import re
import yaml
import os

# Get SystemVerilog Filename
def get_file_stem(j2_file):
    match = re.match(r"^(.*?)(?:\.jinja2)?$", j2_file)
    if match:
        return match.group(1)
    else:
        return j2_file
    
# Load YAML Spec
def load_spec(spec):
    with open(spec, 'r') as fp:
        DUT_spec = yaml.safe_load(fp)

        return DUT_spec
    
# Write UVM Testbench File
def write_testbench(sv_result, uvm_file):
    with open(f'testbench/{uvm_file}', 'w') as fp:
        fp.write(sv_result)

# Write UVM Testbench File via YAML
def write_testbench_from_yaml(sv_result, uvm_file, yaml_path):
    try:
        with open(yaml_path, 'r') as yaml_fp:
            config = yaml.safe_load(yaml_fp)
        
        output_path = config.get('Output_Path')
        if not output_path:
            raise ValueError("Output_Path is not specified in the YAML configuration.")
        
        # Create the directory if it doesn't exist
        os.makedirs(output_path, exist_ok=True)
        
        with open(f'{output_path}/{uvm_file}', 'w') as fp:
            fp.write(sv_result)
    
    except ValueError as e:
        print(f"Error: {e}")
        raise
    except FileNotFoundError:
        print("Error: YAML configuration file not found.")
        raise
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file: {e}")
        raise


def warn_and_confirm_override(yaml_file_path='config.yaml'):
    # Load the YAML file
    with open(yaml_file_path, 'r') as file:
        config = yaml.safe_load(file)
    
    output_path = config.get('Output_Path', 'Output_Path not specified')

    # Warn the user about overriding the path
    print(f"Warning: The contents of the directory '{output_path}' will be overridden.")
    proceed = input("Do you want to proceed? (y/n): ").strip().lower()

    if proceed == 'y':
        print("\n\n#----------------------------------------------------------------------------------------------#")
        print("#  Proceeding with UVM testbench generation...\n#")
        return True
    else:
        print("#  Operation aborted.")
        return False