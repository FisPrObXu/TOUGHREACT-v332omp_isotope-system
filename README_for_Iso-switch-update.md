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
- Only replace species name using:
  
```fortran
rename_species_line(line, newname)
