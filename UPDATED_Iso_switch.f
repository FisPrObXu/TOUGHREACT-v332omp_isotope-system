      PROGRAM ISOSWITCH
C =====================================================================|
C     Program to read TOUGHREACT thermodynamic datafile                | 
C     and add isotopic species (e.g. 52Cr and 53Cr)                    |
C     ChWanner 7/2014                                                  |
C                                                                      |
C     The program considers the following cases:                       |
C     1.Non fractionating mineral dissolution                          |
C     a) isotopic species part of the original stoichiometry           |  
C        (e.g., Cr-Jarosite as in Wanner et al. Comput.Geosci., 2014)  |
C     b) isotopic species not part of the original stoichiometry       |
C        (e.g., Li-biotite as in Wanner et al. Chem. Geol., 2014)      |
C                                                                      |
C     2. Fractionating and non-fractionating mineral precipitation     |
C     a) isotopic species part of the original stoichiometry           |
C        (e.g., Cr(OH)3 as in Wanner and Sonnenthal. Chem.Geol., 2013) |
C     b) isotopic species not part of the original stoichiometry       |
C        (e.g., Li-kaolinite as in Wanner et al. Chem. Geol, 2014)     |
C                                                                      |
C     inp1 = 10  : thermok datafile                                    |
C     iout1= 11  : output file                                         |
C                                                                      |
C     last modified:                                                   |
C                                                                      |
C ---------------------------------------------------------------------|

      implicit double precision(a-h,o-z)
      implicit integer(i-n)
      
      PARAMETER (INP1 = 10, IOUT1 = 11, maxbs=400)
      parameter (nt=8, maxsto=20)

      dimension coef(maxsto),coe(5),coefx(maxsto),coex(5)
      dimension aklog(nt),aklogx(nt)

      character*1 blk,ansdiss,ansstch,anschargebal,ansvalence,anscoef
      character*30 spec(maxsto), specx(maxsto),bspec(maxbs)
      character*4  null
      character*30 name,min_old,iso_more,iso_less,iso_bulk,primspec,
     &   primespec_added,primespec_subst,strip,quote,blank,
     &   second_iso,secspec,min_more,min_less,min_new,
     &   name0,name2
      character*1000 dum, cshort,dum4,dum5,dum6,rename_species_line,
     &   dum7
      character*1  sup
      character*80 filout
      character*4 fdum
      
      real*8   iso_ratio,amreplaced,amount_ad,amount_subst,alpha,addition,minad,ini
     &   h_bal,h2o_bal,scale,coef_more,coef_less 

      DATA blank/'    '/
      DATA null/'null'/
      data iso_bulk/'                              '/

c   Initializations
      do i=1,1000
        dum(i:i) = ' ' 
      enddo

      do i=1,maxbs
       bspec(i)='                               '
      enddo

       do i=1, maxsto
       spec(i)='                              '
       specx(i)='                              '
       enddo
C =====================================================================|


      write(*,"(/5x,'Enter name of data file to read'
     &   /5x,'(default = thermok.dat) :> ',$)")
      filout='thermok.dat'
      call open_old(inp1,filout)

      write(*,"(/5x,'Enter name of the output file'
     &   /5x,'(default = kswitch.out) :> ',$)")
      filout='kswitch.out'
      call open_new(iout1,filout)
      
      write(*,"(/5x,'Enter name of new isotopic species',$)")
      
      
      write(*,"(/5x,'A more abundant isotopic species:> ',$)")
      read(*,"(a30)") iso_more
      
       write(*,"(/5x,'B Less abundant isotopic species:> ',$)")
      read(*,"(a30)") iso_less
      
      write(*,"(/5x,'C Bulk isotopic species (specie to extend):> ',$)")
      read(*,"(a30)") iso_bulk
      
      
      write(*,"(/5x,'Do you want to consider dissolution only? (y/n):> '
     &,$)")
      read(*,"(a1)") ansdiss
      if(ansdiss.eq.'y') then
       write(*,"(5x, 'Is the considered isotopic system part of the orig
     &inal stoichiometry (e.g., Ca in calcite) and thus requires a major
     & element substitution?:> ',$)")
       read(*,"(a1)") ansstch
      		
      		if(ansstch.eq.'y') then
       write(*,"(/5x,'Enter name of mineral to extend for isotopes :> ',
     & $)")
      read(*,"(a30)") min_old
      write(*,"(/5x,'Enter new mineral with isotope extension :> ',$)")
      read(*,"(a30)") min_new
      write(*,"(5x, 'What is the ratio of the more abundant isotopic spe
     &cies to the bulk conc. (depending on delta)?:> ',$)")
       	    read(*,*) iso_ratio
       	    
       	    else if (ansstch.eq.'n') then
       write(*,"(/5x,'Enter name of mineral to extend for isotopes :> ',
     &  $)")
      read(*,"(a30)") min_old
      write(*,"(/5x,'Enter new mineral with isotope extension :> ',$)")
      read(*,"(a30)") min_new
       	    write(*,"(5x, 'Which primary species of the original stoichi
     &ometry should be replaced by the bulk isotopic species? :> ',$)") 
       	    read(*,"(a30)") primspec
       	    write(*,"(5x, 'How much of the original species should be re
     &placed (mol in stoich.)?:> ',$)")
       	    read(*,*) amreplaced
       	    write(*,"(5x, 'Does the defined substitution require any cor
     &rection for maintaining charge balance?:> ',$)")
       	    read(*,"(a30)") anschargebal
       	    	
       	    	if(anschargebal.eq.'n') then
       		write(*,"(5x, 'What is the ratio of the more abundant isotopic
     &species to the bulk species concentration (depending on delta valu
     &e)?:> ',$)")
       	    	read(*,*) iso_ratio
       	    	
       	    	else if (anschargebal.eq.'y') then
       	    write(*,"(5x, 'Primary species to be added/subst. :> ',$)")
       	    	read(*,"(a30)") primespec_added
       	    write(*,"(5x, 'How much is added/subst. (moles)? :> ',$)")
       	    	read(*,*) amount_ad
       	    write(*,"(5x, 'How much H+ has to be added or substituted (m
     &oles) to maintain charge balance?:> ',$)")
                read(*,*) h_bal
                write(*,"(5x, 'How much H2O has to be added or substitut
     &ed (moles) to maintain charge balance?:> ',$)")
                read(*,*) h2o_bal
                write(*,"(5x, 'What is the ratio between the more abunda
     &nt isotopic species to the bulk species concentration (depending o
     &n delta value)?:> ',$)")
       	    read(*,*) iso_ratio
       	    	endif
       	    
       	   
       	    endif
      
      elseif(ansdiss.eq.'n') then
      write(*,"(/5x,'Enter name of mineral to extend for isotopes :> ',
     &  $)")
      read(*,"(a30)") min_old
      write(*,"(/5x,'Enter name of extended phase with more abundant iso
     &tope :> ',$)")
      read(*,"(a30)") min_more
      write(*,"(/5x,'Enter name of extended phase with less abundant iso 
     &tope :> ',$)")
      read(*,"(a30)") min_less
    
      write(*,"(5x, 'Is the considered isotopic system part of the origi
     &nal stoichiometry (e.g., Ca in calcite) and thus requires a major 
     &element substitution?:> ',$)")
      read(*,"(a1)") ansstch
       		
       		if(ansstch.eq.'y') then
      write(*,"(5x, 'Is the stoichiometric coefficient of the bulk isoto
     &pic species equal 1? :> ',$)")
       	    read(*,*) anscoef
      write(*,"(5x, 'What is the isotopic fractionation factor (Rmineral
     &/Rsolution; R=less/more abundant isotopic species):> ',$)")
       	    read(*,*) alpha
      write(*,"(5x, 'Input terminated - Do not forget to define the two  
     &new minerals as solid solution endmembers in file chemical.inp ',$
     &)")
       	    
       	    else if (ansstch.eq.'n') then
       	    write(*,"(5x, 'Input terminated - Do not forget to define th
     &e two new minerals as well as the original mineral as solid soluti
     &on end-members in file chemical.inp and to calibrate the log(K) va
     &lues in the database while considering alpha',$)")    	    	
       	        endif
       	 endif
      
C ---------------------------------------------------------------------|
C     Read database first time to find the species entered above    |
C ---------------------------------------------------------------------|

c     skip records until we find the temperature record
c     Note:strings read in fixed format in thermok file will contain quotes! 
      do
        read (inp1,"(a1000)",end=999) dum
        if(dum(1:14).eq.'!end-of-header') exit
      enddo
c     Reads first record (temperatures)
      read(inp1,*) name, ntemp, (dummy, i=1,ntemp) 
c     Now we are at top of components list
      iflag=0
      i=0
      do 
       read (inp1,"(a1000)",end=1000) dum
       i=i+1 
       read(dum,*, end=1000) name
c       name=strip(dum(1:10)) 
c       if(name(1:10).eq.bs_old(1:10)) then            !found original comp. species
       if(name.eq.iso_bulk) then            !found original comp. species
          write(*,"(/5x,'Found component: ',a30)") iso_bulk
          iflag=1
          cycle        
        endif
        if(dum(2:5).eq.null) exit
      enddo    
      if(iflag.eq.0) goto 1000
      ibstot=i-1
c      Now we are at top of derived species
c      find species that will replace old one       
       do
        read(inp1,"(a1000)", end = 1000) dum
        if(dum(2:5).eq.null) exit
       enddo
       iflag2=0
       do
        read(inp1,"(a1000)",end=1000) dum
        if (len_trim(dum).eq.0) cycle
        if (dum(2:5).eq.null) exit
        read(dum,*, end=1000) name
        if(name.eq.min_old) then            !found original comp. species
          write(*,"(/5x,'Found mineral: ',a30)") min_old
          iflag2=1
          cycle
        endif
       enddo
        if(iflag2.eq.0) goto 1001
        rewind inp1           !back to top of thermok file
C ---------------------------------------------------------------------|
C     Read database file again and add isotopic primary and secondary
c     species as well as isotopic minerals           |
C ---------------------------------------------------------------------|
c
c-- Top part and component species
c 
      write(iout1,"(8x,/'THERMOK with ',a15,' switched with ',a15/)")
     &    iso_bulk, iso_bulk
c     again, skip records until we find the temperature record
      do
        read (inp1,"(a1000)",end=999) dum
        write (iout1,"(a)") trim(dum)
        if(dum(1:14).eq.'!end-of-header') exit
      enddo
       read (inp1,"(a1000)", end=999) dum       !temperature record
      write (iout1,"(a)") trim(dum)

      do i = 1,ibstot
       read(inp1,"(a1000)", end = 1000) dum

       if (len_trim(dum).eq.0) then
         write(iout1,"(a)") ''
         cycle
       endif

       read(dum,*) bspec(i)

       if(bspec(i).eq.iso_bulk) then
         write(iout1,"(a)") trim(rename_species_line(dum,iso_bulk))
         write(iout1,"(a)") trim(rename_species_line(dum,iso_more))
         write(iout1,"(a)") trim(rename_species_line(dum,iso_less))
       else
         write(iout1,"(a)") trim(dum)
       endif
      enddo
c
c     Should be at top of derived species
      read(inp1,"(a1000)", end = 1000) dum
       if (dum(2:5).eq.null) then    !top derived sp. reached
       write(iout1,"(a)") trim(dum) 
      else
       write(*,*) ' Cannot find "null" after components list'
       stop 
      endif
c
c---Derived species
c
      do
   30      read(inp1,"(a1000)", end = 1000) dum

c       Skip blank lines
        if (len_trim(dum).eq.0) then
           write(iout1,"(a)") ''
           cycle
        endif

c       Skip comment lines
         if (index(adjustl(dum),'*').eq.1 .or.
     &       index(adjustl(dum),'#').eq.1) then
            write(iout1,"(a)") trim(dum)
            cycle
         endif

c       End of derived species section
        if(dum(2:5).eq.null) then
           write(iout1,"(a)") trim(dum)
           exit
        endif 

        ios = 0
        read(dum,*,iostat=ios,err=1005) name,wtmol,azero,chg,itot,
     &                 (coef(i), spec(i),i = 1, itot)

        if (ios.ne.0) then
          write(*,*) 'ERROR reading derived-species stoichiometry'
          write(*,*) 'name = ', trim(name)
          write(*,*) 'itot = ', itot
          write(*,*) 'Line content:'
          write(*,*) trim(dum)
          write(*,*) 'iostat = ', ios
          stop
        endif

        read(inp1,*,err=1005,iostat=ios) name, (aklog(i), i = 1, ntemp)
        if (ios < 0) exit
        read(inp1,*,err=1005,iostat=ios) name, (coe(i),i = 1, 5)
        if (ios < 0) exit



c   Writes the data in the output file
         write(dum,"(a30,3x,f10.3,2f6.2,i5,20(f9.4,1x,a30))") 
     &      quote(name),wtmol,azero,chg,
     &      itot, (coef(i), quote(spec(i)),i = 1, itot)
c
c         cshort = short(dum)
         addition=0
         do i=1, itot
         if (spec(i).eq.iso_bulk) then
         addition=addition + 1
         endif
         enddo
         
         if (addition.eq.1) then       
         write(iout1,"(a)") trim(dum)
c         write(iout1,"(a)") trim(short(dum))
         write(iout1,"(a30,5x,8f10.4)") quote(name), 
     &    (aklog(i),i=1,ntemp)
         write(iout1,"(a30,5(3x,e15.8))") quote(name),
     &      (coe(i),i=1, 5)
         
         do i=1, itot
         if(spec(i).eq.iso_bulk) then
         spec(i)=iso_more
         endif
         enddo
         write(dum,"(a30,3x,f10.3,2f6.2,i5,20(f9.4,1x,a30))") 
     &      quote(name),wtmol,azero,chg,
     &      itot, (coef(i), quote(spec(i)),i = 1, itot)
         write(iout1,"(a)") trim(dum)
c         write(iout1,"(a)") trim(short(dum))
         write(iout1,"(a30,5x,8f10.4)") quote(name), 
     &    (aklog(i),i=1,ntemp)
         write(iout1,"(a30,5(3x,e15.8))") quote(name),
     &      (coe(i),i=1, 5)
         do i=1, itot
         if(spec(i).eq.iso_more) then
         spec(i)=iso_less
         endif
         enddo
         write(dum,"(a30,3x,f10.3,2f6.2,i5,20(f9.4,1x,a30))") 
     &      quote(name),wtmol,azero,chg,
     &      itot, (coef(i), quote(spec(i)),i = 1, itot)
         write(iout1,"(a)") trim(dum)
c         write(iout1,"(a)") trim(short(dum))
         write(iout1,"(a30,5x,8f10.4)") quote(name), 
     &    (aklog(i),i=1,ntemp)
         write(iout1,"(a30,5(3x,e15.8))") quote(name),
     &      (coe(i),i=1, 5)        
         elseif(addition.eq.0) then
         write(iout1,"(a)") trim(dum)
c         write(iout1,"(a)") trim(short(dum))
         write(iout1,"(a30,5x,8f10.4)") quote(name), 
     &    (aklog(i),i=1,ntemp)
         write(iout1,"(a30,5(3x,e15.8))") quote(name),
     &      (coe(i),i=1, 5)
         endif 
      enddo
c

c---Gases and minerals
      do
         read(inp1,"(a1000)", end=888) dum

c--------空行
         if (len_trim(dum).eq.0) then
            write(iout1,"(a)") ''
            cycle
         endif

c--------注释
         if(dum(1:1).eq.'*'.or.dum(1:1).eq.'#') then
            write(iout1,"(a)") trim(dum)
            cycle
         endif

c--------section 分隔
         if(dum(2:5).eq.null) then
            write(iout1,"(a)") trim(dum)
            cycle
         endif

c--------读取主行
         ios = 0
         read(dum,*,iostat=ios) name,xmolw,xmolv,itot
         if (ios.ne.0) then
            write(*,*) 'ERROR reading gas/mineral header'
            write(*,*) trim(dum)
            stop
         endif

         if(itot.gt.maxsto) goto 550

         read(dum,*,iostat=ios) name,xmolw,xmolv,itot,
     &        (coef(i), spec(i), i=1,itot)
         if (ios.ne.0) then
            write(*,*) 'ERROR reading gas/mineral stoichiometry'
            write(*,*) trim(dum)
            stop
         endif

         name0 = strip(name)

c--------读第2/3行
         read(inp1,*,err=1002) name, (aklog(i), i = 1, ntemp)
         read(inp1,*,err=1002) name, (coe(i),i = 1, 5)

c--------尝试读取第4行
         dum7 = ' '
         iflag4 = 0
         iblank_after = 0

         read(inp1,"(a1000)",end=41) dum7

         if (len_trim(dum7).eq.0) then
            iblank_after = 1

         else
            ios2 = 0
            read(dum7,*,iostat=ios2) name2
            if (ios2.eq.0) then
               name2 = strip(name2)
               if (name2.eq.name0) then
                  iflag4 = 1
               else
                  backspace(inp1)
               endif
            else
               backspace(inp1)
            endif
         endif
 41      continue

c========================================================
c               ===== 输出逻辑 =====
c========================================================

c--------原矿物
         if(name0.ne.min_old) then
            write(iout1,"(a)") trim(dum)
            write(iout1,"(a30,5x,8f10.4)") quote(name0),
     &         (aklog(i),i=1,ntemp)
            write(iout1,"(a30,5(3x,e15.8))") quote(name0),
     &         (coe(i),i=1,5)

            if (iflag4.eq.1) write(iout1,"(a)") trim(dum7)

c--------目标矿物
         else

c------原矿物保留
            write(iout1,"(a)") trim(dum)
            write(iout1,"(a30,5x,8f10.4)") quote(name0),
     &         (aklog(i),i=1,ntemp)
            write(iout1,"(a30,5(3x,e15.8))") quote(name0),
     &         (coe(i),i=1,5)
            if (iflag4.eq.1) write(iout1,"(a)") trim(dum7)

            write(iout1,"(a)") ''
            
c------min_more
            do i=1,itot
               if(spec(i).eq.iso_bulk) spec(i)=iso_more
            enddo

            name=min_more
            write(dum,"(a30,2x,2g15.7,i5,20(1x,g12.5,1x,a15))")
     &        quote(name),xmolw,xmolv,itot,
     &        (coef(i), quote(spec(i)),i=1,itot)
            write(iout1,"(a)") trim(dum)
            write(iout1,"(a30,5x,8f10.4)") quote(name),
     &         (aklog(i),i=1,ntemp)
            write(iout1,"(a30,5(3x,e15.8))") quote(name),
     &         (coe(i),i=1,5)

            if (iflag4.eq.1) then
               write(iout1,"(a)")
     &          trim(rename_species_line(dum7,min_more))
            endif

            write(iout1,"(a)") ''

c------min_less
            do i=1,itot
               if(spec(i).eq.iso_more) spec(i)=iso_less
            enddo

            name=min_less
            write(dum,"(a30,2x,2g15.7,i5,20(1x,g12.5,1x,a15))")
     &        quote(name),xmolw,xmolv,itot,
     &        (coef(i), quote(spec(i)),i=1,itot)
            write(iout1,"(a)") trim(dum)

            do i=1,ntemp
               if(aklog(i).ne.500)
     &            aklog(i)=aklog(i)-log10(alpha)
            enddo

            write(iout1,"(a30,5x,8f14.8)") quote(name),
     &         (aklog(i),i=1,ntemp)
            write(iout1,"(a30,5(3x,e15.8))") quote(name),
     &         (coe(i),i=1,5)

            if (iflag4.eq.1) then
               write(iout1,"(a)")
     &          trim(rename_species_line(dum7,min_less))
            endif

         endif

c--------恢复空行
         if (iblank_after.eq.1) write(iout1,"(a)") ''

      enddo
  888 continue

c     writes blank end-of-file record and close files
      write (iout1,*)
      close (inp1)
      close (iout1)
      write(*,"(//5x,'.....done!'//)")
      stop 
c
c
c---Error branching
c 
 550  write(*,"(/5x,a30,'number of components=',i5,' maximum=',i5)")
     &     name, itot, maxsto
      stop

 999  continue
      write(*,"(/5x,'End of file encountered before reaching',
     &          ' ""end-of-header"" record in input file')")
      stop
1000  continue
      write(*,"(/5x,'Cannot find primary species to be extended for isotope
     &s:', 1x,'',a30//)") iso_bulk
      stop

1001  continue
      write(*,"(/5x,'Cannot find mineral to be added for isotopes:',
     & 1x,'',a30//)") min_old
      stop

1005  continue
      write(*,"(/5x,'Error reading derived species data')")
      stop
      
1002  continue
      write(*,"(/5x,'Error reading gas/mineral data')")
      stop

2000  continue
      write(*,"(/5x,'Cannot find primary species to be substituted when 
     &adding trace element isotope system:', 1x,'',a30//)") primspec
      stop

2001  continue
      write(*,"(/5x,'Cannot find primary species to be adjusted for main
     &taining charge balance:', 1x,'',a30//)") primespec_added
      stop
      
2002  continue
      write(*,"(/5x,'Cannot find isotopic species in mineral that should
     & be extended for isotopes:', 1x,'',a30//)") iso_bulk
      stop
      
      
      end



      subroutine open_new (iunit,default)
c**********************************
c     Opens a new file (By N.S. 5/98)
c
c         implicit integer (i-n)
c         implicit double precision (a-h,o-z)
      logical exists
      character*80 filenam,default
      character*1 ans
      ifirst=1
      
  10  if(ifirst.eq.0) write(*,"(/5x,'Enter another file name:> ',$)")
      ifirst=0
      read(*,"(a40)") filenam
      if(filenam.eq.' ') filenam = default
      inquire (file = filenam, exist = exists)
      if(exists) then
        write(*,"(5x,'File already exists.  Replace ? (y/n) :>',$)")
        read(*,"(a1)") ans
        if(ans.ne.'Y'.and.ans.ne.'y') goto 10
      end if
      open (unit = iunit, file = filenam, status = 'unknown',err=100)
c
      return
      
100   write(*,"(/'Error while opening the file - stop'/)")
      stop
      end

       subroutine open_old (iunit,default)
c**********************************
c     Opens an old file (By N.S. 5/98)
c
      implicit integer (i-n)
      implicit real (a-h,o-z)
      logical exists
      character*80 filenam,default
c
      ifirst=1
      do
       if(ifirst.eq.0) write(*,"(/5x,'Enter another file name',
     +  ' (or q to quit):> ',$)")
       ifirst=0
       read(*,"(a40)") filenam
       if(filenam.ne.' ') default=filenam
       if((filenam(1:1).eq.'Q'.or.filenam(1:1).eq.'q').and.
     +     filenam(2:2).eq.' ') stop
        inquire (file = default, exist = exists)
       if(exists) then
         open (unit=iunit,file=default,status='old',err=100)
         return
       endif
c
       write(*,"(5x,'Warning! File does not exists!'/)")
      end do
c
100   write(*,"(/'Error while opening the file - stop'/)")
      stop
      end

      function quote(string)
c      
c     returns string in quotes
c
      character* (*) quote
      character* (*) string
c
      quote=''''//trim(string)//''''
      return
      end
      
      character*1000 function rename_species_line(line,newname)
c
c     keeps the whole line unchanged, only replaces the first quoted name
c
      character*(*) line,newname
      integer i1,i2,ll,i
      character*1000 tmp
      character*1 q
      data q /''''/

      tmp = line
      ll = len(line)

      i1 = index(tmp,q)
      if (i1.eq.0) then
         rename_species_line = line
         return
      endif

      i2 = 0
      do i = i1+1, ll
         if (tmp(i:i).eq.q) then
            i2 = i
            goto 10
         endif
      enddo
 10   continue

      if (i2.eq.0) then
         rename_species_line = line
         return
      endif

      rename_species_line = tmp(1:i1-1)//q//trim(newname)//q//
     &                      tmp(i2+1:ll)
      return
      end

      function strip(string)
c      
c     returns string without quotes
c
      character* (*) strip
      character* (*) string
      character*1 blank
      data blank/' '/

c     initialization
      j=len(strip)
      do i=1,j
       strip(i:i)=blank
      enddo 
c      
      ii=0
        do i=1,len(string)
        if(string(i:i).ne.'''') then
           ii=ii+1
           strip(ii:ii)=string(i:i)
        endif
      enddo
      return
      end

      function short(string)
c      
c     returns string without blanks
c
      character* (*) short
      character* (*) string
      character*1 blank
      data blank/' '/

c     initialization
      j=len(short)
      do i=1,j
       short(i:i)=blank
      enddo 
      short(1:30)=string(1:30)
c
      ii=31
      lmax=len(string)
      do i=30,lmax
        ii=ii+1
        short(i:i)=string(ii:ii) 
        if(string(ii:ii).eq.blank.and.string(ii-2:ii-1).eq.''' ')
     &     then
c          skips if more than two blanks after quote 
           nn=ii+1 
           do k=nn,lmax
             if(string(k:k).ne.blank) exit
             ii=ii+1
           enddo
           if(ii.ge.lmax) exit
        endif
      enddo
      return
      end    
      
      
c*********************************************************
      subroutine replace(coef,coe,coefx,coex,aklog,aklogx,div,bs_old,
     &bs_new,spec,specx,itot,itotx,bs_mult,name,ntemp,
     &maxbs,maxsto)
c***********************************************
c
c  To switch the stoichiometries and logK data from
c  bs_old to bs_new.
c
      implicit double precision(a-h,o-z)
      implicit integer(i-n)

      dimension coef(maxsto),coe(5),coefx(maxsto),coex(5)
      dimension aklog(ntemp),aklogx(ntemp),ichk(maxbs)
      dimension coefn(maxsto)
      character*30 spec(maxsto),specx(maxsto)
      character*30 name,bs_old,bs_new
      character*30 specn(maxsto)

c     specx, coefx   species and stoic.coef of reaction to add to others 
c     spec, coef     species and stoic.coef of current reaction being switched

      do i=1,itot
        coefn(i)=coef(i)
        specn(i)=spec(i)
      enddo 
      itotn=itot

c     loops through species in stoichiometry and add them to
c     the stoichiometry of the switche species
      do i=1,itotx+1
        ifind=0
        do j=1,itot
          if(spec(j).eq.specx(i)) then 
           coefn(j)=coefn(j)+bs_mult*coefx(i)
           ifind=1

c          if species in stoichiometry is the species to switch
c          then the coefn calculated above should be zero
           if(spec(j).eq.bs_old) then
             if(coefn(j).ne.0.) then
               write(*,*) ' Program not working with this reaction: '
     &                       ,name 
               stop
             endif
c             coefn(j)=-1.*bs_mult/div
           endif 
           exit
          endif
        enddo  

        if(ifind.eq.0) then
          itotn=itotn+1
          coefn(itotn)=bs_mult*coefx(i)
          specn(itotn)=specx(i) 
        endif          

      enddo


c     save new stoichiometry for printing
      i=0 
      do n=1,itotn
        if(coefn(n).ne.0.) then
          i=i+1
          coef(i)=coefn(n)
          spec(i)=specn(n)
        endif
      enddo  
      itot=i

c     calculate new logK data
      iflg=0
      do i=1,ntemp
         if(aklog(i).ne.500.d0) then
           aklog(i)=aklog(i)+bs_mult*aklogx(i)
         else
           iflg=1
         endif
      enddo
      do i=1,5
         if(iflg.eq.0) then
          coe(i)=coe(i)+bs_mult*coex(i)
         else
          coe(i)=0.d0
          if(i.eq.2) coe(i)=aklog(i)
         endif
      enddo
c
      return
      end 
