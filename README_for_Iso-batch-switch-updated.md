# Sulfur Isotope Database Expander for TOUGHREACT / Thermoddem

A Python tool to generate a **strict sulfur isotope–expanded thermodynamic database** for use in **TOUGHREACT-based reactive transport modeling**.

This tool enables **explicit tracking of sulfur isotopes (³²S / ³⁴S)** in both reduced and oxidized reservoirs by expanding a standard thermodynamic database into isotope-resolved equivalents.

---

## 🔬 Scientific Context

TOUGHREACT is widely used for multiphase reactive transport, but it does not natively support isotope tracking.

Previous work has demonstrated that isotope fractionation can be incorporated into reactive transport frameworks by modifying thermodynamic properties or extending species definitions. For example, isotope-enabled extensions of TOUGHREACT have been developed for water and carbon isotope systems :contentReference[oaicite:0]{index=0}.

However:

> ⚠️ Applications of sulfur isotope fractionation in TOUGHREACT—especially in hydrothermal mineral systems—remain extremely limited.

This tool provides a generalized and automated framework to implement isotope-enabled thermodynamic databases, enabling:

- equilibrium isotope fractionation modeling  
- coupling with hydrothermal reactive transport  
- extension toward ore-forming systems  

---

## 🚀 Features

- Full-database expansion (single run)
- Dual sulfur reservoirs supported:
  - HS⁻ → H³²S⁻ / H³⁴S⁻  
  - SO₄²⁻ → ³²SO₄²⁻ / ³⁴SO₄²⁻  
- Strict combinatorial expansion:
  - No sulfur → 1 species
  - One sulfur basis → 2 isotopic species
  - Two sulfur bases → 4 combinations
- Supports:
  - primary species (1-line)
  - derived aqueous species (3-line blocks)
  - minerals and gases (3–4 line blocks)
- Optional equilibrium fractionation via **logK perturbation**
- Consistent and traceable isotope naming scheme

---

## 📥 Input / 📤 Output

### Input

Standard TOUGHREACT-compatible thermodynamic database:

```text
thdem1214tr3hs5i.dat
```

### Output

Expanded isotope-enabled database:

```text
thdem1214tr3hs5i_S_iso_strict.dat
```

---

## ⚙️ Usage

Run:

```bash
python expand_sulfur_isotope_db_strict.py
```

Modify in script:

```python
INPUT_DB = "your_input.dat"
OUTPUT_DB = "your_output.dat"
```

---

## 🧪 Isotope Definition

Default mapping:

```text
HS-   → H32S- / H34S-
SO4-2 → 32SO4-2 / 34SO4-2
```

---

## 🔁 Expansion Logic (Strict Mode)

| Reaction contains | Output |
|------------------|--------|
| no sulfur        | 1 block |
| HS⁻ only         | 2 blocks |
| SO₄²⁻ only       | 2 blocks |
| HS⁻ + SO₄²⁻      | 4 blocks |

### Example

```text
Hg2+2 + SO4-2 + HS-
```

↓

```text
Hg2+2__HS32__SO432  
Hg2+2__HS34__SO432  
Hg2+2__HS32__SO434  
Hg2+2__HS34__SO434  
```

---

## ⚖️ Isotope Fractionation (Optional)

Fractionation is introduced via equilibrium constant perturbation:

```text
logK_heavy = logK_original - log10(alpha)
```

where:

- α = equilibrium isotope fractionation factor  
- defined as mineral–fluid ratio:

```text
alpha = (34S/32S)_mineral / (34S/32S)_fluid
```

This formulation reflects standard equilibrium isotope fractionation theory, where isotopes partition between phases due to differences in bonding energy :contentReference[oaicite:1]{index=1}.

### Example

```python
ALPHA_RULES = {
    "Pyrite": {"HS-": 1.001},
    "Anhydrite": {"SO4-2": 1.002},
}
```

✔ Only applied to heavy isotope variants  
✔ Multiple sulfur bases are treated independently (additive in log-space)

---

## ⚠️ Important Assumptions

- Fractionation is treated as equilibrium-only  
- α is assumed constant (temperature-independent) unless user modifies  
- No explicit isotope mass balance tracking  
- No kinetic isotope fractionation (e.g., microbial processes)  

---

## 🧠 Limitations

- TOUGHREACT does not natively support isotopes  
- Isotope effects are introduced indirectly via thermodynamic shifts  
- Database size increases significantly (2×–4×)  
- Mixed HS⁻ + SO₄²⁻ reactions may represent non-physical mixing pathways if not carefully interpreted  

---

## 🧩 Recommended Workflow

1. Prepare original thermodynamic database  
2. Run expansion script  
3. Validate output (format + species consistency)  
4. Update `chemical.inp` manually  
5. Run TOUGHREACT simulation  
6. Post-process isotope signals (δ³⁴S)  

---

## 🔭 Advanced Extensions (Future Work)

Temperature-dependent fractionation:

```text
1000 ln(alpha) = A/T^2 + B/T + C
```

- Kinetic isotope fractionation (e.g., sulfate reduction)  
- Coupled isotope mass balance tracking  
- Integration with PHREEQC / CrunchTope benchmarks  

---

## 📌 Positioning

This tool is best understood as:

> A framework for implementing isotope-enabled reactive transport modeling in TOUGHREACT

rather than a standard preprocessing utility.

It is particularly suited for:

- hydrothermal systems  
- ore-forming processes  
- water–rock interaction studies  

---

## 👤 Author

Developed for advanced isotope-enabled hydrothermal system modeling.
