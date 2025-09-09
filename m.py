import os

def list_folder_contents(root_folder, output_file):
    """
    Walks through a folder and its subfolders, writing the name and content
    of each file to the provided output file object.
    """
    # Check if the folder exists
    if not os.path.isdir(root_folder):
        error_message = f"Error: The folder '{root_folder}' does not exist."
        print(error_message) # Print error to terminal for immediate feedback
        output_file.write(error_message + '\n')
        return

    output_file.write(f"--- Starting Scan of Folder: {root_folder} ---\n\n")

    # os.walk() goes through all folders and subfolders
    for foldername, subfolders, filenames in os.walk(root_folder):
        output_file.write(f"--- Directory: {foldername} ---\n")

        # Now, loop through all the files in the current directory
        for filename in filenames:
            # Create the full path to the file
            full_path = os.path.join(foldername, filename)

            output_file.write(f"\n=========================================\n")
            output_file.write(f"File Path: {full_path}\n")
            output_file.write(f"=========================================\n")

            try:
                # Open and read the file's content
                with open(full_path, 'r', encoding='utf-8', errors='ignore') as file_content:
                    content = file_content.read()
                    output_file.write("--- Content Start ---\n")
                    output_file.write(content)
                    output_file.write("\n--- Content End ---\n\n")

            except Exception as e:
                # This will catch other errors, like not having permission to read a file
                output_file.write(f"[Could not read file. Reason: {e}]\n\n")


# --- MAIN PART OF THE SCRIPT ---
if __name__ == "__main__":
    # !!! IMPORTANT !!!
    # 1. Change the path below to the folder you want to scan.
    target_folder = 'D:\\SDPProject\\retainly\\lib'

    # 2. This will be the name of the file the script creates.
    output_filename = 'folder_contents.txt'

    print(f"Starting scan... Output will be saved to '{output_filename}'")

    # Open the output file in write mode ('w')
    with open(output_filename, 'w', encoding='utf-8') as outfile:
        list_folder_contents(target_folder, outfile)

    print("Scan complete! Your file is ready.")