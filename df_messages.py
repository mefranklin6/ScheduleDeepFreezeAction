import inputValues

# gets sent from main
config = None


###############################################################################

def make_footer():
    footer = f'''This is an automated email from {config["Emails"]["Support_Name"]}
Please contact {config["Emails"]["Support_Email"]} for any changes or issues'''
    return footer

###############################################################################

def make_force_description(force:bool):
    if force == True:
        force_description = '''Please make sure all programs on the PC are closed, including Zoom, PowerPoint, etc.
To prevent disruption, automatic action will not be taken if there are signs of user activity.
To skip checking, please re-schedule and set the 'Force' flag.'''
    
    if force == False:
        force_description = '''Warning: Force flag is set.
Reboot commands will be sent REGARDLESS of user activity on the machine'''
    
    return force_description

###############################################################################

def make_schedule_email(force_description, footer):
    scheduled_email = f"""From: {config['Emails']['From_Name']}
To: {inputValues.requestor_email}
Subject: Deep Freeze Action Scheduled


PC: {inputValues.pc_name}
Scheduled to reboot {inputValues.status}
At: {inputValues.time}

You will receive a follow up email once action has been taken.

{force_description}

{footer}
"""
    return scheduled_email

###############################################################################

def make_success_email(footer):
    success_email = f"""From: {config['Emails']['From_Name']}
To: {inputValues.requestor_email}
Subject: Deep Freeze Action Sucessful


PC: {inputValues.pc_name}
Has Sucessfully Rebooted {inputValues.status}


{footer}
"""
    return success_email

###############################################################################

def make_failure_email(footer, log_data):
    failure_email = f"""From: {config['Emails']['From_Name']}
To: {inputValues.requestor_email}
Subject: Deep Freeze Action FAILURE


PC: {inputValues.pc_name}
FAILED to reboot {inputValues.status}

Manual action may be required.

Log: 


{log_data}


{footer}
"""
    return failure_email

###############################################################################

