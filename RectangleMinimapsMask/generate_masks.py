from PIL import Image, ImageDraw, ImageFont

for i in range(0, 127):
    image = Image.new(mode='RGBA', size=(256, 256), color=(255, 255, 255, 255))
    draw_table = ImageDraw.Draw(im=image)
    draw_table.rectangle([0, 0, 256, i], (255, 255, 255, 0))
    draw_table.rectangle([0, 256-i, 256, 256], (255, 255, 255, 0))
    image.save('masks/{}.png'.format(128-i), 'PNG')
