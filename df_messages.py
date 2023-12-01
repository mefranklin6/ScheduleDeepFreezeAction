###############################################################################


def make_footer(support_name, support_email):
    footer = f"""This is an automated email from {support_name}
Please contact {support_email} for any changes or issues"""
    return footer


###############################################################################


def make_force_description(force: bool):
    if force == False:
        force_description = """Please make sure all programs on the PC are closed, including Zoom, PowerPoint, etc.
To prevent disruption, automatic action will not be taken if there are signs of user activity.
To skip checking, please re-schedule and set the 'Force' flag."""

    if force == True:
        force_description = """Warning: Force flag is set.
Reboot commands will be sent REGARDLESS of user activity on the machine"""

    return force_description


###############################################################################


def make_schedule_email(
    force_description, footer, from_name, to_email, pc, desired_state, scheduled_time
):
    scheduled_email = f"""From: {from_name}
To: {to_email}
Subject: Deep Freeze Action Scheduled


PC: {pc}
Scheduled to reboot {desired_state}
At: {scheduled_time}

You will receive a follow up email once action has been taken.

{force_description}

{footer}
"""
    return scheduled_email


###############################################################################


def make_success_email(from_name, to_email, pc, confirmed_state, footer):
    success_email = f"""From: {from_name}
To: {to_email}
Subject: Deep Freeze Action Sucessful


PC: {pc}
Has Sucessfully Rebooted {confirmed_state}


{footer}
"""
    return success_email


###############################################################################


def make_failure_email(from_name, to_email, pc, desired_state, footer, log_data):
    failure_email = f"""From: {from_name}
To: {to_email}
Subject: Deep Freeze Action FAILURE


PC: {pc}
FAILED to reboot {desired_state}

Manual action may be required.

Log: 


{log_data}


{footer}
"""
    return failure_email


###############################################################################
