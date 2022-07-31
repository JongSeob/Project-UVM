import openpyxl
from jinja2 import Environment, FileSystemLoader
import os
from os.path import join

# OPEN JINJA TEMPLATE #

PATH = os.path.dirname(os.path.abspath(__file__));
TEMPLATE_ENVIRONMENT = Environment(
        autoescape=False,
        loader=FileSystemLoader(os.path.join(PATH, 'VERIFICATION/tb')),
        trim_blocks=False)

# REDNERING #

def render_template(template_filename, context):
    return TEMPLATE_ENVIRONMENT.get_template(template_filename).render(context)

# MAKE NEW OUTPUT FILE #

def create_index_uvm(data):
    root_dir = 'output/VERIFICATION/tb'
    createFolder(root_dir)
    fname = "top.sv";
    context = {
            'name'   : data['project'].value,
            'driver' : data['driver'].value,
            'monitor': data['monitor'].value,
            'seq'    : data['seq'].value
            }
    with open(join(root_dir, fname), 'w') as f:
            top = render_template('PROJECT_top.sv.jj2', context)
            f.write(top)



# CREATE DIR #
def createFolder(directory):
    try:
        if not os.path.exists(directory):
            os.makedirs(directory)
    except OSError:
        print ('Error: Creating directory. ' + directory)




def main():
    book = openpyxl.load_workbook('input.xlsx')
    sheet = book.active

    data = {'project':0, 
            'driver' :0,
            'monitor':0,
            'seq'    :0
            };

    data['project'] = sheet['A2']
    data['driver' ] = sheet['B5']
    data['monitor'] = sheet['B6']
    data['seq'    ] = sheet['B7']


    create_index_uvm(data)


if __name__ == "__main__":
    main()
    
