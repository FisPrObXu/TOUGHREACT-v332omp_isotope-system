Iso_switch.f 原本用于在热力学数据库中为目标组分和矿物生成同位素扩展项，但在处理当前数据库时暴露出一系列兼容性和稳健性问题，主要包括：
空行、注释行处理不稳，容易触发 EOF 或误读。
component species 重写时丢失原始参数。
gas/mineral 区默认按固定 3 行结构读取，无法兼容 4 行矿物。
矿物块之间的空白分隔行被吞掉，导致上下矿物“粘连”。
部分矿物第一行被重新格式化后出现 "********"。
新生成矿物的名称、内部物种和附加第 4 行之间可能不一致。
老式 fixed-form Fortran 下存在续行、函数返回类型、跨块 goto 等兼容性问题。

本次优化的目标不是简单修补单一报错，而是提升程序对实际数据库格式的兼容性、可诊断性和输出保真度。

**1. component species 优化**

1.1 问题
原程序在扩展 HS- 时，只读取并重写了前四项：

name
azero
charge
molecular weight

导致原始行后面的扩散系数、活化能、注释等全部丢失。

例如原始：

'HS-'  1.80 -1.00  33.0700  1.1297E-07  1.0e4  ...

输出后变成：

'HS-'  1.80 -1.00  33.070
'H32S-' ...
'H34S-' ...

这会导致数据库信息不完整。

1.2 策略

采用“整行保留，仅替换 species 名称”的策略，不再重新格式化 component species 行。

1.3 具体实现

新增字符函数 rename_species_line(line,newname)：

保留整行所有原始字段
只替换最前面的 quoted species 名称
适用于：
HS-
H32S-
H34S-

这样输出可以保持：

原始参数
原始精度
原始注释

**2. 空行和注释处理优化**

2.1 问题

原程序在多个段落中：

不跳过空行，导致空字符串参与 read(dum,*)
把空行当成结束条件
对注释行判断过于脆弱
在 peek 第 4 行时会把空行和注释行直接吞掉

导致：

EOF
gas/mineral 读错
矿物块粘连
注释丢失

2.2 策略

统一使用：

if (len_trim(dum).eq.0)

判断空行，而不再依赖：

dum(1:4).eq.'    '

2.3 结果

空行处理更加明确，避免：

空字符串解析失败
段落被提前终止
固定宽度字符比较带来的误判

**3. derived species 段优化**

3.1 问题

derived species 段在内部读字符串时，若遇到空行或异常格式，原程序只会报笼统错误，无法定位问题。

3.2 策略

对 derived species header 和 stoichiometry 的读取加入：

iostat=ios
原始行打印
itot 合法性检查

3.3 收益

可以快速定位是：

空行问题
itot 与组分数不一致
格式异常
特定 species 记录损坏

**4. gas/mineral 区兼容 4 行矿物**

4.1 问题

原程序默认 gas/mineral 条目结构为 3 行：

主定义行
logK 行
coe 行

但真实数据库中存在大量 4 行矿物，例如：

主定义行
logK 行
coe 行
附加热力学/物性参数行

原程序会把第 4 行误当成下一条矿物主定义行，导致：

Error reading gas/mineral data
后续矿物整体错位

4.2 策略

在读完前 3 行后，增加“peek 一行”机制：

读入 dum7
若该行首个名称与当前矿物 name0 相同，则判断为同一矿物的第 4 行
设置 iflag4 = 1
否则 backspace(inp1)，留给下一轮正常处理

4.3 关键改进

不能依赖某个数值字段判断是否为矿物，例如 xmolv.gt.0.1，因为真实矿物中该列可能为负值，如：

'Acanthite(alpha)' 247.8020 -34.2000 ...

因此最终采用的是：

基于“下一行名称是否与当前条目同名”来识别第 4 行

这个策略比基于数值条件的判断更稳。

**5. 空白分隔行恢复**

5.1 问题

在 dum7 peek 过程中，如果下一行是空白分隔行，原程序会把它读掉，但不写回，导致：

上下矿物块粘连
原数据库段落风格丢失

5.2 策略

引入标志位：

iblank_after

逻辑为：

若 dum7 是空行，则设置 iblank_after = 1
当前矿物块全部写完后，再统一补回一个空行：
if (iblank_after.eq.1) write(iout1,"(a)") ''

5.3 效果

恢复矿物块之间的空白分隔，使输出数据库更接近原始风格，也更便于人工检查。

**6. 矿物第 4 行写回策略**

6.1 问题

即使程序已经识别了 dum7，如果输出分支没有把它写回，4 行矿物仍会变成 3 行。

6.2 策略

对每个矿物输出块，在第三行之后补写第 4 行：

原矿物
if (iflag4.eq.1) write(iout1,"(a)") trim(dum7)
min_more
if (iflag4.eq.1) then
   write(iout1,"(a)")
     & trim(rename_species_line(dum7,min_more))
endif
min_less
if (iflag4.eq.1) then
   write(iout1,"(a)")
     & trim(rename_species_line(dum7,min_less))
endif
min_new
if (iflag4.eq.1) then
   write(iout1,"(a)")
     & trim(rename_species_line(dum7,min_new))
endif

6.3 核心原则

第 4 行与主块的命名必须保持一致：

原矿物 → 原样
新矿物 → 只改矿物名，保留其余内容

**7. 矿物第一行重构策略**

7.1 问题

这是最关键的认识之一。

对于 min_more / min_less / min_new，不能简单用：

rename_species_line(dum,min_more)

只改矿物名。

因为矿物第一行中不仅有矿物名，还有内部反应物种，例如：

... 'HS-'

而在生成 Pyrite_32 / Pyrite_34 时，行内物种本身也发生了变化：

HS- → H32S-
HS- → H34S-

如果只改矿物名而不重构第一行，那么数据库会内部自相矛盾。

7.2 正确策略

原矿物

直接保留原始第一行：

write(iout1,"(a)") trim(dum)
component species

只改名称，整行保留。

min_more / min_less / min_new

必须根据当前已经修改后的：

name
coef(i)
spec(i)
itot

重新构造第一行。

**8. 第一行格式宽度优化**

8.1 问题

原程序在重构矿物第一行时使用的格式过窄，例如：

(a30,3x,2f10.3,i5,20(f9.4,1x,a15))

会导致：

数值风格变化过大
宽度不够时输出 "********"
可读性变差

8.2 策略

将第一行格式改宽，采用更宽松的数值格式，例如：

(a30,2x,2g15.7,i5,20(1x,g12.5,1x,a15))

或其他更宽的浮点字段。

8.3 收益

减少：

"********"
非必要的精度丢失
极端数值导致的字段溢出

**9. 新矿物块之间主动分隔**

9.1 问题

像：

Pyrite
Pyrite_32
Pyrite_34

这类连续生成的新矿物块，如果不主动插入空行，就会连在一起，虽然可能仍可读，但风格不佳，也不利于检查。

9.2 策略

在写完一个完整矿物块后，如果还要继续写另一个新矿物块，则主动加：

write(iout1,"(a)") ''

9.3 目的

让：

原矿物
min_more
min_less

各自成块，保持数据库结构清晰。

**10. fixed-form Fortran 兼容性修复**

10.1 问题

Iso_switch.f 是老式 .f fixed-form Fortran，存在以下兼容性问题：

长行超过 72 列
自由格式 & 续行写法非法
新函数未声明返回类型
goto 跨块跳转产生 warning
exit 在老式代码里兼容性一般

10.2 策略

函数声明

显式声明：

character*1000 rename_species_line
长行改为 fixed-form 续行

例如：

write(iout1,"(a)")
     & trim(rename_species_line(dum7,min_more))
goto 40 改为 cycle

在循环内部使用 cycle 替代跨块跳转。

exit 改为老式 goto

在函数内部搜索字符时，使用：

goto 10

替代 exit，增强兼容性。

**11. 调试与诊断能力增强**

11.1 策略

对关键读取点增加：

iostat=ios
原始行打印
name、itot 输出

11.2 收益

使程序能够从“黑箱崩溃”变成“可定位具体坏行”的状态。
这对处理真实数据库非常重要，因为数据库格式往往并非完全统一。
