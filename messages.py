import inputValues
from main import config

# gets sent from main
log_data = None


###############################################################################
footer = f'''This is an automated email from {config["Emails"]["Support_Name"]}
Please contact {config["Emails"]["Support_Email"]} for any changes or issues'''

###############################################################################
scheduled_email = f"""From: {config['Emails']['From_Name']}
To: {inputValues.requestor_email}
Subject: Deep Freeze Action Scheduled


PC: {inputValues.pc_name}
Scheduled to reboot {inputValues.status}
At: {inputValues.time}

You will receive a follow up email once action has been taken.

Please make sure all programs on the PC are closed, including Zoom, PowerPoint, etc.
To prevent disruption, automatic action will not be taken if there are signs of user activity.

{footer}
"""

###############################################################################
success_email = f"""From: {config['Emails']['From_Name']}
To: {inputValues.requestor_email}
Subject: Deep Freeze Action Sucessful


PC: {inputValues.pc_name}
Has Sucessfully Rebooted {inputValues.status}


{footer}
"""
###############################################################################

failure_email = f"""From: {config['Emails']['From_Name']}
To: {inputValues.requestor_email}
Subject: Deep Freeze Action FAILURE


PC: {inputValues.pc_name}
FAILED to reboot {inputValues.status}

Manual action may be needed.  CTS has been alerted.

Log: 


{log_data}


{footer}
"""
###############################################################################

if __name__ == '__main__':
    pass