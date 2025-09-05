import os
from convert import convert_css_to_rgb


def read_css_file(file_path):
    """
    Read CSS file and return its contents as a list of lines

    Args:
        file_path: Path to CSS file

    Returns:
        List of lines from the file
    """
    with open(file_path, "r", encoding="utf-8") as f:
        return f.readlines()


def write_lua_file(file_path, color_dict):
    """
    Write color dictionary to Lua file

    Args:
        file_path: Path to output Lua file
        color_dict: Dictionary of color names to hex values
    """
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local tailwindColor = {\n")

        for color_name, hex_value in color_dict.items():
            f.write(f'    ["{color_name}"] = "{hex_value}",\n')

        f.write("}\n\nreturn tailwindColor\n")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))

    input_file = os.path.join(script_dir, "tailwind-color.txt")
    output_file = os.path.join(script_dir, "tailwind-color.lua")

    css_lines = read_css_file(input_file)

    color_dict = {}
    for line in css_lines:
        line = line.strip()
        if not line:
            continue

        result = convert_css_to_rgb(line)
        if result:
            color_name, hex_color = result
            color_dict[color_name] = hex_color

    write_lua_file(output_file, color_dict)

    print(f"Conversion complete! {len(color_dict)} colors converted.")
    print(f"Output written to {output_file}")


if __name__ == "__main__":
    main()
