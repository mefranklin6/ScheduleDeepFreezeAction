import tkinter as tk
from tkinter import ttk
#from tkcalendar import DateEntry
from subprocess import run
import schedule, yaml, smtplib
import inputValues, df_messages
from time import sleep

with open('Config.yaml', 'r') as file:
    config = yaml.safe_load(file)


df_messages.config = config
footer = df_messages.make_footer()


# replace with full path if having issues
pwsh_script_path = 'Execute_DF_Action.ps1'


##### GUI STUFF #####
root = tk.Tk()

# PC Name text field
tk.Label(root, text="PC Name").grid(row=0)
pc_name = tk.Entry(root)
pc_name.grid(row=0, column=1)

# Requestor Email
tk.Label(root, text="Requestor Email").grid(row=1)
email = tk.Entry(root)
email.grid(row=1, column=1)

# TODO: Date selector
#tk.Label(root, text="Date").grid(row=2)
#date = DateEntry(root)
#date.grid(row=2, column=1)

# Hour selector
tk.Label(root, text="Hour (24 Hour Clock)").grid(row=3)
hour = tk.Spinbox(root, from_=0, to=24, format="%02.0f")
hour.grid(row=3, column=1)

# Minute selector
tk.Label(root, text="Minute").grid(row=4)
minute = tk.Spinbox(root, from_=0, to=59, format="%02.0f")
minute.grid(row=4, column=1)

# Force checkbox
force = tk.BooleanVar()  # This variable will hold the state of the checkbox
force.set(False)  # default state
tk.Checkbutton(root, text="Force", variable=force).grid(row=5, column=1)

# Status selector
tk.Label(root, text="Status").grid(row=6)
status = ttk.Combobox(root, values=["Frozen", "Thawed", "Thawed and Locked"])
status.grid(row=6, column=1)


def submit():
    pc_name_value = pc_name.get()
    email_value = email.get()
#   date_value = date.get_date()
    time_value = f'{hour.get()}:{minute.get()}'
    force_value = force.get()
    status_value = status.get()

    print("PC Name: ", pc_name_value)
    print("Email: ", email_value)
#   print("Date: ", date_value)
    print("Time: ", time_value)
    print("Force:" , force_value)
    print("Desired State: ", status_value)
    root.destroy()

    inputValues.pc_name = pc_name_value
    inputValues.requestor_email = email_value
#   inputValues.date = date_value
    inputValues.time = time_value
    inputValues.force = force_value
    inputValues.status = status_value


# Submit button
tk.Button(root, text="Submit", command=submit).grid(row=7)

root.mainloop()


#### Email Stuff ####

EMAIL_TO = [f'{inputValues.requestor_email}', f'{config["Emails"]["Email_CC"]}']

def SendEmail(
        email_to, 
        email_from, 
        email_msg
    ):
    
    try:    
        smtpObj = smtplib.SMTP(config['SMTP_Server'])    
        smtpObj.sendmail(email_from, email_to, email_msg)    
        print("INFO: Successfully sent email")    
    except Exception:    
        print("ERROR: unable to send email")


#### Confirmation ####
def CheckResult():
    try:
        with open(
                f'{config["Utils"]["Log_Directory"]}{inputValues.pc_name}.txt',
                'r',
                encoding='UTF-16'
        ) as f:
            
            log_data = f.read().strip()
            
        
        if 'DeepFreezeActionResult: True' in log_data:
            Result_email_body = df_messages.make_success_email(footer)

        elif 'DeepFreezeActionResult: False' in log_data:
            Result_email_body = df_messages.make_failure_email(footer, log_data)

        else:
            print('UNCAUGHT EXCEPTION')

        # Results email
        SendEmail(
                EMAIL_TO,
                config['Emails']['Email_From'], 
                Result_email_body
                )

        
    except FileNotFoundError:
        print('File does not exist.')


#### Actions ####
def main():
    run([
        'powershell.exe',
         pwsh_script_path, 
         inputValues.pc_name, 
         inputValues.status,
         config['Utils']['Log_Directory'],
         inputValues.force,
         None
         ]
    ) 
    '''
        str:PC
        str:DesiredState
        str:EncryptedPasswordLocation
        str:LogLocation
        bool:Force
        int:RebootTimeout - optional    
    '''
    
    sleep(1)
    CheckResult()
    return exit()


# Send 'action scheduled' email
SendEmail(
    EMAIL_TO,
    config['Emails']['Email_From'],
    df_messages.scheduled_email
    )


#### Schedule Stuff ####
schedule.every().day.at(inputValues.time).do(main)

while True:
    schedule.run_pending()
    sleep(1)
