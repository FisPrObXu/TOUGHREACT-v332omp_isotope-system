# Sulfur Isotope Database Expander for TOUGHREACT / Thermoddem

A Python tool to generate a **strict sulfur isotope-expanded thermodynamic database** from TOUGHREACT / Thermoddem `.dat` files.

This tool enables **simultaneous isotope tracking of reduced sulfur (HS⁻) and oxidized sulfur (SO₄²⁻)** by automatically expanding:

- primary species
- derived aqueous species
- mineral / gas phases

into isotope-resolved equivalents.

---

## Features

- Full-database expansion (one run)
- Supports dual sulfur reservoirs:
  - HS⁻ → H32S⁻ / H34S⁻
  - SO₄²⁻ → 32SO₄²⁻ / 34SO₄²⁻
- Strict mode expansion:
  - No sulfur → 1 species
  - One sulfur basis → 2 isotopic species
  - Two sulfur bases → 4 isotopic combinations
- Handles:
  - primary species (single-line)
  - derived species (3-line blocks)
  - minerals / gases (3–4 line blocks)
- Optional fractionation (alpha) support for minerals
- Consistent naming convention for isotope variants

---

## Input / Output

### Input

A TOUGHREACT-compatible thermodynamic database, for example:

thdem1214tr3hs5i.dat

### Output

A fully expanded isotope-aware database:

thdem1214tr3hs5i_S_iso_strict.dat

---

## Usage

Run:

python expand_sulfur_isotope_db_strict.py

Modify settings inside the script:

INPUT_DB = "your_input.dat"
OUTPUT_DB = "your_output.dat"

---

## Isotope Definition

Default:

HS-   → H32S- / H34S-  
SO4-2 → 32SO4-2 / 34SO4-2  

---

## Expansion Logic (Strict Mode)

| Reaction contains | Output |
|------------------|--------|
| no sulfur        | 1 block |
| HS⁻ only         | 2 blocks |
| SO₄²⁻ only       | 2 blocks |
| HS⁻ + SO₄²⁻      | 4 blocks |

Example:

Hg2+2 + SO4-2 + HS-

→

Hg2+2__HS32__SO432  
Hg2+2__HS34__SO432  
Hg2+2__HS32__SO434  
Hg2+2__HS34__SO434  

---

## Fractionation (optional)

Example:

ALPHA_RULES = {
    "Pyrite": {"HS-": 1.001},
    "Anhydrite": {"SO4-2": 1.002},
}

Applied as:

logK_new = logK_original - log10(alpha)

Only affects heavy isotope variants.

---

## Notes

- This tool modifies thermodynamic databases, not simulation inputs
- chemical.inp must be updated manually
- database size increases significantly (2–4×)
- mixed HS⁻ + SO₄²⁻ reactions represent mixed sulfur sources

---

## Recommended Workflow

1. Prepare original database  
2. Run expansion script  
3. Validate output (structure, species, consistency)  
4. Update chemical.inp  
5. Run TOUGHREACT  

---

## Author

Developed for isotope-enabled hydrothermal system modeling.
