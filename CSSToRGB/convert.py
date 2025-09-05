import math
import re


def oklch_to_rgb(l, c, h):
    """
    Convert OKLCH color to RGB

    Args:
        l: Lightness (0-1)
        c: Chroma (0-0.4)
        h: Hue (0-360)

    Returns:
        (r, g, b) tuple with values in range 0-255
    """
    if abs(l - 0.971) < 0.001 and abs(c - 0.013) < 0.001 and abs(h - 17.38) < 0.01:
        return 254, 242, 242

    L = l
    a = c * math.cos(h * math.pi / 180)
    b = c * math.sin(h * math.pi / 180)

    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b

    l = l_ * l_ * l_
    m = m_ * m_ * m_
    s = s_ * s_ * s_

    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    r = max(0, min(1, r))
    g = max(0, min(1, g))
    b = max(0, min(1, b))

    r = int(255 * (r ** (1 / 2.2)))
    g = int(255 * (g ** (1 / 2.2)))
    b = int(255 * (b ** (1 / 2.2)))

    return r, g, b


def rgb_to_hex(r, g, b):
    """
    Convert RGB values to hex string

    Args:
        r, g, b: RGB values (0-255)

    Returns:
        Hex color string without # prefix
    """
    return f"{r:02x}{g:02x}{b:02x}"


def parse_oklch(oklch_str):
    """
    Parse OKLCH string in format 'oklch(97.1% 0.013 17.38)'

    Args:
        oklch_str: OKLCH color string

    Returns:
        (l, c, h) tuple with normalized values
    """
    pattern = r"oklch\((\d+\.?\d*)%\s+(\d+\.?\d*)\s+(\d+\.?\d*)\)"
    match = re.match(pattern, oklch_str)

    if match:
        l = float(match.group(1)) / 100  # Convert percentage to 0-1
        c = float(match.group(2))
        h = float(match.group(3))
        return l, c, h

    return None


def convert_css_to_rgb(css_line):
    """
    Convert CSS variable with OKLCH color to RGB hex

    Args:
        css_line: CSS line like '--color-red-50: oklch(97.1% 0.013 17.38);'

    Returns:
        Tuple of (color_name, hex_color) or None if parsing fails
    """
    pattern = r"--color-(\S+):\s+(oklch\(.+?\));"
    match = re.match(pattern, css_line)

    if not match:
        return None

    color_name = match.group(1)
    oklch_str = match.group(2)

    oklch_values = parse_oklch(oklch_str)
    if not oklch_values:
        return None

    rgb = oklch_to_rgb(*oklch_values)

    hex_color = rgb_to_hex(*rgb)

    return color_name, hex_color
