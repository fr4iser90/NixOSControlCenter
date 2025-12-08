# Example notifier: Sends notifications/alerts/messages
# Notifiers handle communication to users/systems

{ pkgs, lib, ui, ... }:

{
  notify = message: ''
    # Example: Send notification
    ${ui.messages.info "$message"}
    
    # Example: Send email
    # echo "$message" | ${pkgs.mailutils}/bin/mail -s "Notification" user@example.com
    
    # Example: Send to systemd journal
    # systemd-cat echo "$message"
  '';
}

