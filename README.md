# ScheduleDeepFreezeAction
Tool for scheduling actions using the Faronics Deep Freeze CLI

Open sourcing here is in-process.  I will remove this line when the repo is feature-complete.

If you manage PC's with Faronics Deep Feeeze installed, this tool allows you to schedule frozen/thawed actions.

Not associated with the company Faronics, makers of Deep Freeze

Requirements:
    Powershell v7 or above.
    (Note that Windows 10/11 only ships with v5.1)

    Python 
    (written with 3.11)

Security Considerations:
    Because of a limitation in the Deep Freeze CLI, there are brief times that the Deep Freeze password
    is loaded into RAM as a plain-text string.  That also means that the encrypted password stored on disk
    can be decrypted into plain-text, but only by the user that encrypted the password, and
    only on the machine that the password was origionally encrypted.  
    The password is sent over the wire encrypted, as all things are with WinRM, but is also briefly in RAM as plain-text on the target.
    Therefore please note that the potential for a password to be read by an unauthorized party is very small but not zero.