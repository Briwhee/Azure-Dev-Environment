add-content -path c:/Users/brian/.ssh/config -value @'

Host ${hostname}
    HostName ${hostname}
    User ${user}
    IdentityFile ${identityfile}
'@