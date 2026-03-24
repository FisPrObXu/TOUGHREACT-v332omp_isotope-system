# IsoSwitch Robust Version for Thermodynamic Databases

This repository provides an enhanced version of `Iso_switch.f` for generating isotope-extended thermodynamic databases (TOUGHREACT / Thermoddem compatible).

The original IsoSwitch implementation is designed to extend target species and minerals with isotopic variants. However, when applied to real-world databases, it exhibits multiple robustness and compatibility issues.

This work focuses on **systematically improving stability, format compatibility, and output fidelity**, rather than patching isolated errors.

---

## 🔧 Key Improvements

### 1. Component Species Preservation

**Problem**
- Original code rewrites only partial fields (name, charge, MW)
- Loses diffusion coefficients, activation energy, and comments

**Solution**
- Full-line preservation strategy
- Only replace species name via:

```fortran
rename_species_line(line, newname)
```

**Result**
- Original precision, parameters, and comments fully retained

---

### 2. Robust Blank & Comment Handling

**Problem**
- Blank lines treated as data
- Fragile fixed-width checks (`'    '`)
- Comments and separators lost
- Causes EOF errors and block corruption

**Solution**
- Unified detection:

```fortran
if (len_trim(dum).eq.0)
```

**Result**
- Stable parsing without premature termination or structure loss

---

### 3. Derived Species Diagnostics

**Problem**
- Format errors are not traceable

**Solution**
- Add:
  - `iostat` checks
  - raw line logging
  - `itot` validation

**Result**
- Precise identification of malformed entries

---

### 4. Support for 4-Line Minerals

**Problem**
- Original code assumes 3-line structure
- Misinterprets 4th line as a new mineral

**Solution**
- Introduce a **peek mechanism**:
  - Read next line (`dum7`)
  - If same name → treat as 4th line
  - Else → `backspace`

**Key Principle**
- Use **name consistency**, not numeric thresholds

---

### 5. Preservation of Blank Separators

**Problem**
- Peek operation consumes blank lines
- Mineral blocks become concatenated

**Solution**
- Track blank lines using `iblank_after`
- Restore them after writing the block

**Result**
- Original structure and readability preserved

---

### 6. Consistent 4th-Line Handling

**Problem**
- 4th line may be detected but not written back

**Solution**
- Always write 4th line after each mineral block
- Only rename species name if needed

---

### 7. Correct Reconstruction of Mineral Header

**Critical Insight**

The mineral first line contains both:
- mineral name
- internal reaction species

Therefore:

> Renaming a mineral requires reconstructing the entire line

**Strategy**
- Original mineral → keep unchanged
- New isotopic minerals → rebuild using updated species

---

### 8. Improved Output Formatting

**Problem**
- Narrow formats cause `********`
- Precision loss

**Solution**

```fortran
(a30,2x,2g15.7,i5,20(1x,g12.5,1x,a15))
```

**Result**
- No overflow
- Better numerical stability

---

### 9. Explicit Block Separation

**Problem**
- Generated minerals merge together (e.g., Pyrite_32, Pyrite_34)

**Solution**
- Insert blank line between generated blocks

---

### 10. Fixed-Form Fortran Compatibility

**Issues**
- Line length limits (>72 columns)
- Invalid continuation
- Implicit typing
- Unsafe `goto`

**Fixes**
- Explicit function typing
- Proper continuation (`&`)
- Replace `goto` with `cycle` where possible
- Use classic `goto` only where required

---

### 11. Enhanced Debugging Capability

**Added**
- `iostat` tracking
- raw line output
- contextual diagnostics

**Result**
- From black-box failure → traceable debugging

---

## 🎯 Design Philosophy

This upgrade is not a patchwork fix.

It aims to:

- Preserve original database fidelity
- Handle real-world format variability
- Provide diagnosable and stable behavior
- Ensure compatibility with heterogeneous datasets

---

## ⚠️ Notes

- This tool modifies **thermodynamic databases**, not simulation inputs
- Users must ensure:
  - consistency with `chemical.inp`
  - correct isotope interpretation
- Manual inspection is still recommended for complex databases

---

## 📌 Recommended Workflow

1. Apply IsoSwitch to the original database
2. Inspect output structure
3. Validate:
   - species consistency
   - mineral block integrity
   - isotope definitions
4. Integrate into TOUGHREACT workflow

---

## 👨‍🔬 Author

Developed for robust isotope-enabled hydrothermal modeling workflows.
