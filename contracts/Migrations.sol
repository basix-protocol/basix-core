/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity >=0.4.21 <0.7.0;

contract Migrations {
    address public owner;
    uint public last_completed_migration;

    constructor() public {
        owner = msg.sender;
    }

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    function setCompleted(uint completed) public restricted {
        last_completed_migration = completed;
    }

    function upgrade(address new_address) public restricted {
        Migrations upgraded = Migrations(new_address);
        upgraded.setCompleted(last_completed_migration);
    }
}
