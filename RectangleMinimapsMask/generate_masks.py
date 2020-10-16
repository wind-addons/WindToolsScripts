from PIL import Image, ImageDraw, ImageFont

for i in range(0, 99):
    image = Image.new(mode='RGBA', size=(200, 200), color=(255, 255, 255, 255))
    draw_table = ImageDraw.Draw(im=image)
    draw_table.rectangle([0, 0, 200, i], (255, 255, 255, 0))
    draw_table.rectangle([0, 200-i, 200, 200], (255, 255, 255, 0))
    image.save('masks/{}.png'.format(100-i), 'PNG')
