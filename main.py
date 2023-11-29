from __future__ import annotations

import tkinter as tk
from tkinter import ttk
# from tkcalendar import DateEntry
from subprocess import run
import schedule
import yaml
import smtplib
import df_input_values
import df_messages
from time import sleep

with open('Config.yaml', 'r') as file:
    config = yaml.safe_load(file)


# replace with full path if having issues
pwshExecute_script_path = './Execute_DF_Action.ps1'

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
# tk.Label(root, text="Date").grid(row=2)
# date = DateEntry(root)
# date.grid(row=2, column=1)

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
    state = status.get()

    print("PC Name: ", pc_name_value)
    print("Email: ", email_value)
#   print("Date: ", date_value)
    print("Time: ", time_value)
    print("Force:", force_value)
    print("Desired State: ", state)
    root.destroy()

    df_input_values.pc_name = pc_name_value
    df_input_values.requestor_email = email_value
#   inputValues.date = date_value
    df_input_values.time = time_value
    df_input_values.force = force_value
    df_input_values.state = state


# Submit button
tk.Button(root, text="Submit", command=submit).grid(row=7)

root.mainloop()


#### Email Stuff ####

FOOTER = df_messages.make_footer(
    config['Emails']['Support_Name'],
    config['Emails']['Support_Email']
)

EMAIL_TO = [f'{df_input_values.requestor_email}',
            f'{config["Emails"]["Email_CC"]}']

SMTP_PASSWORD = config['Emails']['SMTP_Password']


def SendEmail(
    email_to,
    email_from,
    email_msg
):

    try:
        smtpObj = smtplib.SMTP(config['Emails']['SMTP_Server'])

        # FIXME: make it so there's no plain-text password stored anywhere
        if SMTP_PASSWORD is not None and SMTP_PASSWORD != '':
            smtpObj.login(config['Emails']['SMTP_User'], SMTP_PASSWORD)

        smtpObj.sendmail(email_from, email_to, email_msg)
        print('INFO: Successfully sent email')
    except Exception as e:
        print(f'ERROR: unable to send email, {e}')


#### Confirmation ####

def FormatEmailBody(pwsh_exit_code) -> str('result_email-body' or None):

    if pwsh_exit_code == 0:
        Result_email_body = df_messages.make_success_email(
            config['Emails']['From_Name'],
            df_input_values.requestor_email,
            df_input_values.pc_name,
            df_input_values.state,
            FOOTER
        )
        return (Result_email_body)

    elif pwsh_exit_code == 1:
        with open(
            f'{config["Utils"]["Log_Directory"]}/{df_input_values.pc_name}.txt',
            'r',
            encoding='UTF-8'
        ) as f:

            log_data = f.read().strip()
            # to get only the most recent data
            this_log_data = log_data.split(
                '---------------------------------------')[-1]

        Result_email_body = df_messages.make_failure_email(
            config['Emails']['From_Name'],
            df_input_values.requestor_email,
            df_input_values.pc_name,
            df_input_values.state,
            FOOTER,
            this_log_data
        )
        return (Result_email_body)

    else:
        print('UNCAUGHT EXCEPTION')
        return (None)


#### Actions ####

def main():

    pwsh_result = run(
        [
            'pwsh.exe',  # powershell 7, needed for password decrypt
            pwshExecute_script_path,
            df_input_values.pc_name,
            df_input_values.state,
            config['Utils']['Encryped_PW_Location'],
            config['Utils']['Log_Directory'],
            str(df_input_values.force),
        ]
    )
    '''
        str:PC
        str:DesiredState
        str:EncryptedPasswordLocation
        str:LogLocation
        str:Force 
    '''

    result_email_body = FormatEmailBody(pwsh_result.returncode)

    SendEmail(
        EMAIL_TO,
        config['Emails']['Email_From'],
        result_email_body
    )

    return exit()


# Send 'action scheduled' email
FORCE_DESCRIPTION = df_messages.make_force_description(df_input_values.force)

scheduled_email = df_messages.make_schedule_email(
    FORCE_DESCRIPTION,
    FOOTER,
    config['Emails']['From_Name'],
    df_input_values.requestor_email,
    df_input_values.pc_name,
    df_input_values.state,
    df_input_values.time
)

SendEmail(
    EMAIL_TO,
    config['Emails']['Email_From'],
    scheduled_email
)


#### Schedule Stuff ####
schedule.every().day.at(df_input_values.time).do(main)

while True:
    schedule.run_pending()
    sleep(1)
