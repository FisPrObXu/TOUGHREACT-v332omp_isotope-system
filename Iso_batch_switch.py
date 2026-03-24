import re
import math
from itertools import product
from pathlib import Path

# =========================================================
# USER SETTINGS
# =========================================================

INPUT_DB = "thdem1214tr3hs5i.dat"
OUTPUT_DB = "thdem1214tr3hs5i_S_iso_strict.dat"

# Isotope naming already consistent with your current database
ISOTOPE_BASIS = {
    "HS-": {
        "light": "H32S-",
        "heavy": "H34S-",
    },
    "SO4-2": {
        "light": "32SO4-2",
        "heavy": "34SO4-2",
    },
}

# Optional fractionation factors for heavy-isotope variants only.
# Applied as: logK_new = logK_old - log10(alpha)
# Example:
ALPHA_RULES = {
    "Pyrite": {"HS-": 1.0010},
    "Anhydrite": {"SO4-2": 1.0020},
    "Hg2+2": {"HS-": 1.0005, "SO4-2": 1.0002},
}
# ALPHA_RULES = {}

# Keep original sulfur basis species in primary section
KEEP_ORIGINAL_PRIMARY = True

# Insert a blank line after each generated block group
INSERT_BLANK_LINE_BETWEEN_BLOCKS = True

# TOUGHREACT chemical.inp mineral name limit
MAX_NAME_LEN = 20


# =========================================================
# BASIC HELPERS
# =========================================================

def split_tokens(line: str):
    return re.findall(r"'[^']*'|\S+", line)

def strip_q(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and s[0] == "'" and s[-1] == "'":
        return s[1:-1]
    return s

def quote(s: str) -> str:
    return f"'{s}'"

def is_blank(line: str) -> bool:
    return len(line.strip()) == 0

def is_comment(line: str) -> bool:
    s = line.lstrip()
    return s.startswith("*") or s.startswith("#")

def is_null(line: str) -> bool:
    s = line.strip()
    return s.startswith("null") or s.startswith("'null'")

def first_quoted_name(line: str):
    m = re.match(r"\s*'([^']+)'", line)
    return m.group(1) if m else None

def safe_float(x: str):
    return float(x.replace("D", "E").replace("d", "e"))


# =========================================================
# DATA CLASS
# =========================================================

class ReactionBlock:
    """
    section:
        'derived' or 'mineral'

    header_tokens:
        derived -> [name, MW, azero, charge, itot]
        mineral -> [name, xmolw, xmolv, itot]

    stoich_pairs:
        [(coef_str, species_name), ...]
    """
    def __init__(self, section, name, header_tokens, stoich_pairs,
                 logk_vals, coeff_vals, extra_line=None):
        self.section = section
        self.name = name
        self.header_tokens = header_tokens
        self.stoich_pairs = stoich_pairs
        self.logk_vals = logk_vals
        self.coeff_vals = coeff_vals
        self.extra_line = extra_line

    def used_sulfur_basis(self):
        used = []
        for _, sp in self.stoich_pairs:
            if sp in ISOTOPE_BASIS:
                used.append(sp)
        return sorted(set(used))


# =========================================================
# PRIMARY SECTION
# =========================================================

def is_primary_candidate_line(line: str) -> bool:
    """
    Primary species line format is single-line, e.g.
    'SO4-2'  3.15 -2.00 96.064 1.2336E-07 1.17e4  ! comment
    """
    if is_blank(line) or is_comment(line) or is_null(line):
        return False
    toks = split_tokens(line)
    return len(toks) >= 6 and toks[0].startswith("'")

def expand_primary_line(line: str):
    """
    Only expand if the primary species itself is a sulfur basis species.
    Keep original line if KEEP_ORIGINAL_PRIMARY=True, then append isotope variants.
    """
    if not is_primary_candidate_line(line):
        return [line]

    toks = split_tokens(line)
    name = strip_q(toks[0])

    if name not in ISOTOPE_BASIS:
        return [line]

    out = []

    if KEEP_ORIGINAL_PRIMARY:
        out.append(line)

    for state in ["light", "heavy"]:
        new_toks = toks[:]
        new_toks[0] = quote(ISOTOPE_BASIS[name][state])
        out.append(" ".join(new_toks) + "\n")

    return out


# =========================================================
# DERIVED SECTION PARSER
# =========================================================

def parse_derived_block(lines, i):
    """
    Derived species block:
    line1: 'name' MW azero charge itot coef1 'spec1' coef2 'spec2' ...
    line2: 'name' logK1 logK2 ...
    line3: 'name' c1 c2 c3 c4 c5
    """
    if i + 2 >= len(lines):
        raise ValueError("Not enough lines for derived block")

    l1, l2, l3 = lines[i], lines[i + 1], lines[i + 2]

    toks1 = split_tokens(l1)
    if len(toks1) < 5:
        raise ValueError("Derived line1 too short")

    name = strip_q(toks1[0])
    itot = int(float(toks1[4]))
    header_tokens = toks1[:5]
    rest = toks1[5:]

    if len(rest) != 2 * itot:
        raise ValueError(
            f"Derived stoichiometry mismatch for {name}: "
            f"expected {2 * itot}, got {len(rest)}"
        )

    pairs = []
    for j in range(0, len(rest), 2):
        coef = rest[j]
        spec = strip_q(rest[j + 1])
        pairs.append((coef, spec))

    toks2 = split_tokens(l2)
    toks3 = split_tokens(l3)

    if len(toks2) < 2 or len(toks3) < 2:
        raise ValueError(f"Derived block incomplete for {name}")

    if strip_q(toks2[0]) != name or strip_q(toks3[0]) != name:
        raise ValueError(f"Derived block name mismatch near {name}")

    logk_vals = toks2[1:]
    coeff_vals = toks3[1:]

    return ReactionBlock(
        section="derived",
        name=name,
        header_tokens=header_tokens,
        stoich_pairs=pairs,
        logk_vals=logk_vals,
        coeff_vals=coeff_vals,
        extra_line=None,
    ), 3


# =========================================================
# MINERAL / GAS SECTION PARSER
# =========================================================

def parse_mineral_block(lines, i):
    """
    Mineral/gas block:
    line1: 'name' xmolw xmolv itot coef1 'spec1' coef2 'spec2' ...
    line2: 'name' logK...
    line3: 'name' coeff...
    optional line4: 'name' ...
    """
    if i + 2 >= len(lines):
        raise ValueError("Not enough lines for mineral block")

    l1, l2, l3 = lines[i], lines[i + 1], lines[i + 2]

    toks1 = split_tokens(l1)
    if len(toks1) < 4:
        raise ValueError("Mineral line1 too short")

    name = strip_q(toks1[0])
    itot = int(float(toks1[3]))
    header_tokens = toks1[:4]
    rest = toks1[4:]

    if len(rest) != 2 * itot:
        raise ValueError(
            f"Mineral stoichiometry mismatch for {name}: "
            f"expected {2 * itot}, got {len(rest)}"
        )

    pairs = []
    for j in range(0, len(rest), 2):
        coef = rest[j]
        spec = strip_q(rest[j + 1])
        pairs.append((coef, spec))

    toks2 = split_tokens(l2)
    toks3 = split_tokens(l3)

    if len(toks2) < 2 or len(toks3) < 2:
        raise ValueError(f"Mineral block incomplete for {name}")

    if strip_q(toks2[0]) != name or strip_q(toks3[0]) != name:
        raise ValueError(f"Mineral block name mismatch near {name}")

    logk_vals = toks2[1:]
    coeff_vals = toks3[1:]

    extra_line = None
    step = 3

    if i + 3 < len(lines):
        l4 = lines[i + 3]
        if not is_blank(l4) and not is_comment(l4) and not is_null(l4):
            nm4 = first_quoted_name(l4)
            if nm4 == name:
                extra_line = l4
                step = 4

    return ReactionBlock(
        section="mineral",
        name=name,
        header_tokens=header_tokens,
        stoich_pairs=pairs,
        logk_vals=logk_vals,
        coeff_vals=coeff_vals,
        extra_line=extra_line,
    ), step


# =========================================================
# COMPACT NAMING RULE FOR chemical.inp + .tec UNIQUENESS
# =========================================================

def compact_state_prefix(state_map: dict) -> str:
    """
    Dual-basis:
        m22 = HS32 + SO432
        m24 = HS32 + SO434
        m42 = HS34 + SO432
        m44 = HS34 + SO434

    Single-basis:
        h2 = HS32 only
        h4 = HS34 only
        s2 = SO432 only
        s4 = SO434 only
    """
    has_hs = "HS-" in state_map
    has_so4 = "SO4-2" in state_map

    if has_hs and has_so4:
        hs_digit = "2" if state_map["HS-"] == "light" else "4"
        so4_digit = "2" if state_map["SO4-2"] == "light" else "4"
        return f"m{hs_digit}{so4_digit}"

    if has_hs:
        hs_digit = "2" if state_map["HS-"] == "light" else "4"
        return f"h{hs_digit}"

    if has_so4:
        so4_digit = "2" if state_map["SO4-2"] == "light" else "4"
        return f"s{so4_digit}"

    return ""

def rename_block_name(base_name: str, state_map: dict) -> str:
    """
    Naming rule examples:
        m22_magnetite
        m24_magnetite
        m42_magnetite
        m44_magnetite

        h2_h2s(aq)
        h4_h2s(aq)

        s2_anhydrite
        s4_anhydrite

    Prefix-first naming is safer for .tec output because the distinguishing
    isotope code appears at the beginning, reducing truncation collisions.
    """
    if not state_map:
        return base_name

    prefix = compact_state_prefix(state_map)
    new_name = f"{prefix}_{base_name}"

    if len(new_name) > MAX_NAME_LEN:
        print(f"[WARN] Name exceeds {MAX_NAME_LEN} chars: {new_name}")

    return new_name


# =========================================================
# STRICT ISOTOPIC EXPANSION
# =========================================================

def generate_state_combinations(used_basis):
    """
    Strict mode:
        no sulfur basis -> 1 block
        one sulfur basis -> 2 blocks
        two sulfur bases -> 4 blocks
    """
    if not used_basis:
        return [dict()]

    used_basis = sorted(used_basis)
    combos = []
    for states in product(["light", "heavy"], repeat=len(used_basis)):
        combos.append(dict(zip(used_basis, states)))
    return combos

def replace_stoich_pairs(pairs, state_map):
    new_pairs = []
    for coef, spec in pairs:
        if spec in state_map:
            new_spec = ISOTOPE_BASIS[spec][state_map[spec]]
            new_pairs.append((coef, new_spec))
        else:
            new_pairs.append((coef, spec))
    return new_pairs

def apply_alpha_shift(original_name: str, state_map: dict, logk_vals):
    shift = 0.0

    if original_name in ALPHA_RULES:
        for basis, state in state_map.items():
            if state == "heavy":
                alpha = ALPHA_RULES[original_name].get(basis, 1.0)
                shift += math.log10(alpha)

    if shift == 0.0:
        return logk_vals[:]

    shifted = []
    for x in logk_vals:
        try:
            v = safe_float(x)
            if v != 500.0:
                v = v - shift
            shifted.append(f"{v:.8f}")
        except Exception:
            shifted.append(x)
    return shifted

def expand_reaction_block(block: ReactionBlock):
    used_basis = block.used_sulfur_basis()
    state_maps = generate_state_combinations(used_basis)

    expanded = []
    for sm in state_maps:
        new_name = rename_block_name(block.name, sm)
        new_pairs = replace_stoich_pairs(block.stoich_pairs, sm)
        new_logk = apply_alpha_shift(block.name, sm, block.logk_vals)

        expanded.append(
            ReactionBlock(
                section=block.section,
                name=new_name,
                header_tokens=block.header_tokens[:],
                stoich_pairs=new_pairs,
                logk_vals=new_logk,
                coeff_vals=block.coeff_vals[:],
                extra_line=block.extra_line,
            )
        )

    return expanded


# =========================================================
# WRITERS
# =========================================================

def format_reaction_block(block: ReactionBlock):
    out = []

    # line 1
    header = block.header_tokens[:]
    header[0] = quote(block.name)

    if block.section == "derived":
        header[4] = str(len(block.stoich_pairs))
    elif block.section == "mineral":
        header[3] = str(len(block.stoich_pairs))

    line1_parts = header[:]
    for coef, spec in block.stoich_pairs:
        line1_parts.append(coef)
        line1_parts.append(quote(spec))
    out.append(" ".join(line1_parts) + "\n")

    # line 2
    out.append(" ".join([quote(block.name)] + block.logk_vals) + "\n")

    # line 3
    out.append(" ".join([quote(block.name)] + block.coeff_vals) + "\n")

    # optional line 4
    if block.extra_line is not None:
        toks4 = split_tokens(block.extra_line)
        if toks4 and toks4[0].startswith("'"):
            toks4[0] = quote(block.name)
            out.append(" ".join(toks4) + "\n")
        else:
            out.append(block.extra_line)

    return out


# =========================================================
# SECTION LOCATORS
# =========================================================

def find_end_of_header(lines):
    for i, line in enumerate(lines):
        if line.startswith("!end-of-header"):
            return i
    raise RuntimeError("Cannot find !end-of-header")

def find_nth_null(lines, start_idx, n):
    count = 0
    for i in range(start_idx, len(lines)):
        if is_null(lines[i]):
            count += 1
            if count == n:
                return i
    raise RuntimeError(f"Cannot find the {n}-th null after line {start_idx}")

def looks_like_mineral_start(lines, i):
    if i + 2 >= len(lines):
        return False
    if is_blank(lines[i]) or is_comment(lines[i]) or is_null(lines[i]):
        return False
    try:
        parse_mineral_block(lines, i)
        return True
    except Exception:
        return False


# =========================================================
# MAIN
# =========================================================

def process_database():
    lines = Path(INPUT_DB).read_text(encoding="utf-8", errors="ignore").splitlines(True)

    header_end = find_end_of_header(lines)

    # structure:
    # header_end
    # temp line = header_end + 1
    # primary section until first null after temp line
    # derived section until second null
    # mineral/gas section after second null
    first_null = find_nth_null(lines, header_end + 2, 1)
    second_null = find_nth_null(lines, header_end + 2, 2)

    out = []

    # -----------------------------------------------------
    # 1) header
    # -----------------------------------------------------
    out.extend(lines[:header_end + 1])

    # -----------------------------------------------------
    # 2) temperature line
    # -----------------------------------------------------
    temp_idx = header_end + 1
    out.append(lines[temp_idx])

    # -----------------------------------------------------
    # 3) primary section
    # -----------------------------------------------------
    i = temp_idx + 1
    while i < first_null:
        line = lines[i]
        if is_blank(line) or is_comment(line):
            out.append(line)
        else:
            out.extend(expand_primary_line(line))
        i += 1

    out.append(lines[first_null])

    # -----------------------------------------------------
    # 4) derived section
    # -----------------------------------------------------
    i = first_null + 1
    while i < second_null:
        line = lines[i]

        if is_blank(line) or is_comment(line):
            out.append(line)
            i += 1
            continue

        block, step = parse_derived_block(lines, i)
        expanded = expand_reaction_block(block)

        for eb in expanded:
            out.extend(format_reaction_block(eb))
            if INSERT_BLANK_LINE_BETWEEN_BLOCKS:
                out.append("\n")

        i += step

    out.append(lines[second_null])

    # -----------------------------------------------------
    # 5) mineral / gas section
    # -----------------------------------------------------
    i = second_null + 1
    while i < len(lines):
        line = lines[i]

        if is_blank(line) or is_comment(line) or is_null(line):
            out.append(line)
            i += 1
            continue

        if looks_like_mineral_start(lines, i):
            block, step = parse_mineral_block(lines, i)
            expanded = expand_reaction_block(block)

            for eb in expanded:
                out.extend(format_reaction_block(eb))
                if INSERT_BLANK_LINE_BETWEEN_BLOCKS:
                    out.append("\n")

            i += step
        else:
            out.append(line)
            i += 1

    Path(OUTPUT_DB).write_text("".join(out), encoding="utf-8")
    print(f"[DONE] Wrote: {OUTPUT_DB}")


if __name__ == "__main__":
    process_database()
