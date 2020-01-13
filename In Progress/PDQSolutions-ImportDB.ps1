<#
.SYNOPSIS
    Simplify importing new databases into PDQ Inventory and/or Deploy
.DESCRIPTION
    Importing a database involves several manual steps - 
    | stop relevant product processes (PDQDeployConsole and PDQInventoryConsole) and services (PDQDeploy and PDQInventory)
    | rename existing DB
    | copy new DB from file share to current machine
    | rename new DB
    | restart relevant product processes and services

    This attempts to automate all the above, as well as offering the option to revert back to the original DB when done testing the new DB.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    Nothing fancy about this yet. Maybe eventually
#>

