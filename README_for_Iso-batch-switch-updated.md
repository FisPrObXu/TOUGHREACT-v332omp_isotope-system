# Sulfur Isotope Database Expander for TOUGHREACT / Thermoddem

A Python tool to generate a **strict sulfur isotope-expanded thermodynamic database** from TOUGHREACT / Thermoddem `.dat` files.

This tool enables **simultaneous isotope tracking of reduced sulfur (HS⁻) and oxidized sulfur (SO₄²⁻)** by automatically expanding:

- primary species
- derived aqueous species
- mineral / gas phases

into isotope-resolved equivalents.

---

## ✨ Features

- 🔁 **Full-database expansion (one run)**
- 🧪 Supports **dual sulfur reservoirs**:
  - HS⁻ → H32S⁻ / H34S⁻
  - SO₄²⁻ → 32SO₄²⁻ / 34SO₄²⁻
- 🧩 **Strict mode expansion**
  - No sulfur → 1 species
  - One sulfur basis → 2 isotopic species
  - Two sulfur bases → 4 isotopic combinations
- ⚙️ Handles:
  - primary species (single-line)
  - derived species (3-line blocks)
  - minerals / gases (3–4 line blocks)
- 🧮 Optional **fractionation (α) support** for minerals
- 🏷 Consistent naming convention for isotope variants

---

## 📦 Input / Output

### Input

A TOUGHREACT-compatible thermodynamic database, e.g.:
