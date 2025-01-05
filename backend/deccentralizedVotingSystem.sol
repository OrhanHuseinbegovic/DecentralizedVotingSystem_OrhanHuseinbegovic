// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract VotingSystem{

    enum UserType {
        Unassigned,
        Voter,
        VotePublisher
    }

    enum Status{
        Pending,
        Active,
        Finished
    }

    address[] public addresses;

    struct VotingPoll {
        uint256 id;
        string name;
        string description;
        address votePublisher;
        uint256 timeLeft;
        Status status;
    }

    struct VotingOption {
        uint256 id;
        string name;
        uint256 voteCount;
    }

    uint256 public votingPollCounterID = 0;
    mapping(uint256 => VotingPoll) public votingPolls;
    mapping(uint256 => VotingOption[]) public votingOptionsByPoll;
    mapping(uint256 => bool) public hasStarted;
    mapping(address => UserType) public userRoles;
    //Address of the user points to the ID of the voting poll and if he has voted
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(uint256 => bool) isFinished;
    
    event newVote(address _address, uint256 _votingPollID, uint256 _currentTime);
    event newPollCreated(address _votePublisher, uint _pollID, uint256 _currentTime);
    event newOptionCreated(uint256 _votingPollID, uint _votingOptionID, uint256 _currentTime);
    event userLoggedIn(address indexed _userAddress, UserType _userType, uint256 _currentTimestamp);
    event addedNewUser(address indexed _userAddress, uint256 _currentTimestamp);
    event pollDeleted(address indexed _userAddress, uint256 _votingPollID, uint256 _currentTimestamp);
    event optionDeleted(address indexed _userAddress, uint256 _votingPollID, uint256 _votingOptionID, uint256 _currentTimestamp);

    modifier isVoter() {
        require(userRoles[msg.sender] == UserType.Voter, "Only Voter can perform this action");
        _;
    }

    modifier hasNotVoted (uint _votingPollID) {
        require(hasVoted[msg.sender][_votingPollID] == false, "You can only vote once for this voting poll!");
        _;
    }

    // Check if user is a VotePublisher
    modifier onlyVotePublisher() {
        require(userRoles[msg.sender] == UserType.VotePublisher, "Only VotePublisher can perform this action");
        _;
    }

    // Check if user is the poll owner
    modifier onlyPollOwner(uint256 _votingPollID) {
        require(votingPolls[_votingPollID].votePublisher == msg.sender, "Only the owner of the poll can perform this action");
        _;
    }

    modifier isActive(uint256 _votingPollID) {
        require(votingPolls[_votingPollID].status == Status.Active, "Can't vote for a non-active poll!");
        _;
    }

    modifier isNotPublisher(uint256 _votingPollID) {
        require(votingPolls[_votingPollID].votePublisher != msg.sender, "Vote publisher can not vote for his/hers voting poll");
        _;
    }

    modifier hasNotFinished(uint256 _votingPollID) {
        require(votingPolls[_votingPollID].timeLeft > block.timestamp, "Poll time has finished!");
        _;
    }

    modifier isNotPending(uint256 _votingPollID) {
        require(votingPolls[_votingPollID].status != Status.Pending, "Poll is pending!");
        _;
    }

    /*
        Function to check if the provided address exists inside
        of the addresses array, if yes, it will be logged, else
        address will be added to the array and the new user
        will be logged. User type will be selected on 
    */
    function checkAddress(address _address, UserType _userType) public {
        if (userRoles[_address] == UserType.Unassigned) { 
            addresses.push(_address);
            userRoles[_address] = _userType;
            emit addedNewUser(_address, block.timestamp);
            emit userLoggedIn(_address, userRoles[_address], block.timestamp);
        } else {
            userRoles[_address] = _userType;
            emit userLoggedIn(_address, _userType, block.timestamp);
        }
    }

    function createPoll(string memory _name, string memory _description,uint256 _timeLeft) onlyVotePublisher public {
        require(_timeLeft >= 43200, "Duration of the Voting Poll must be bigger or equal to 12h !");
        VotingPoll memory votingPoll;
        votingPoll.id = votingPollCounterID;
        votingPoll.name = _name;
        votingPoll.description = _description;
        votingPoll.votePublisher = msg.sender;
        votingPoll.timeLeft = _timeLeft;
        votingPoll.status = Status.Pending;
        votingPolls[votingPollCounterID] = votingPoll;
        hasStarted[votingPollCounterID] = false;
        emit newPollCreated(msg.sender, votingPollCounterID++, block.timestamp);
    }

    function addVotingOption(uint256 _votingPollID, string memory _name) onlyPollOwner(_votingPollID) public {
        require(hasStarted[_votingPollID] == false, "Voting poll has started, can't add voting options now!");
        require(votingPolls[_votingPollID].status == Status.Pending, "Voting poll has finished or started, can't add voting options now!");
        VotingOption memory votingOption;
        votingOption.id = votingOptionsByPoll[_votingPollID].length;
        votingOption.name = _name;
        votingOption.voteCount = 0;
        votingOptionsByPoll[_votingPollID].push(votingOption);
        emit newPollCreated(msg.sender, votingOption.id, block.timestamp);
    }

    /*
        Delete Voting Poll made by Voting Publisher that is Pending
        mapping(uint256 => VotingPoll) public votingPolls;
    */
    function deletePendingPoll(uint256 _votingPollID) onlyVotePublisher onlyPollOwner(_votingPollID) public returns (string memory) {
        require(hasStarted[_votingPollID] == false, "Voting poll has started, can't delete poll!");
        require(votingPolls[_votingPollID].status == Status.Pending, "Voting poll has finished or started, can't delete poll now!");
        require(isFinished[_votingPollID] == false, "ERROR: Voting poll is ACTIVE!");
        string memory name = votingPolls[_votingPollID].name;
        delete votingPolls[_votingPollID];
        emit pollDeleted(msg.sender, _votingPollID, block.timestamp);
        return name;
    }

    //Delete the voting option of the voting poll by replacing the last
    //element of the voting options array to the position of the
    //current element that the user wants to delete, and put the
    //element to be deleted on the last place, and then pop it.
    function deleteVotingOption(uint256 _votingPollID, uint256 _votingOptionID) onlyVotePublisher onlyPollOwner(_votingPollID) public returns (string memory) {
        string memory name = votingOptionsByPoll[_votingPollID][_votingOptionID].name;
        votingOptionsByPoll[_votingPollID][_votingOptionID] = votingOptionsByPoll[_votingPollID][votingOptionsByPoll[_votingPollID].length-1];
        votingOptionsByPoll[_votingPollID].pop();
        emit optionDeleted(msg.sender, _votingPollID, _votingOptionID, block.timestamp);
        return name;
    }

    function startVotingPoll(uint256 _votingPollID) onlyPollOwner(_votingPollID) public {
        require(votingOptionsByPoll[_votingPollID].length >= 2, "Need at least 2 voting options to start voting!");
        require(hasStarted[_votingPollID] == false, "Voting poll already started!");
        require(isFinished[_votingPollID] == false, "Voting poll has finished and can't be started again!");
        votingPolls[_votingPollID].status = Status.Active; 
        votingPolls[_votingPollID].timeLeft += block.timestamp; 
        hasStarted[_votingPollID] = true;
    }

    function getVotingPollName(uint256 _votingPollID) public view returns (string memory){
        return votingPolls[_votingPollID].name;
    }

    function getVotingPollDescription(uint _votingPollID) public view returns (string memory) {
        return votingPolls[_votingPollID].description;
    }

    function getVotingPollTime(uint256 _votingPollID) public view returns (uint256){
        return votingPolls[_votingPollID].timeLeft;
    }

    function getVotingPollStatus(uint _votingPollID) public view returns (Status) {
        return votingPolls[_votingPollID].status;
    }

    

    /*
        This function should be called every time any function is called on the webserver for convenience,
        but we can't do this since every transaction then will have a fee. So, only
        reasonable solution is to CALL this function whenever
        any of the users wan't to vote for a certain option in a poll. So
        firstly call this functio, then check if the poll has been ended, if not, 
        vote, else, revert the function.
    */
    function endVotingPoll(uint256 _votingPollID) private {
        if(block.timestamp >= votingPolls[_votingPollID].timeLeft){
            votingPolls[_votingPollID].status = Status.Finished;
            hasStarted[_votingPollID] = false; 
            isFinished[_votingPollID] = true;
        }
    } 

    function endVotingPolls() public {
        for(uint256 i=0; i<votingPollCounterID; i++){
            if(block.timestamp >= votingPolls[i].timeLeft){
                votingPolls[i].status = Status.Finished;
                hasStarted[i] = false; 
                isFinished[i] = true;
            }
        }
    } 

    function checkPolls() public view returns(bool)  {
        for(uint256 i=0; i<votingPollCounterID; i++){
            if(block.timestamp >= votingPolls[i].timeLeft){
                return true;
            }
        }
        return false;
    } 

    function checkHasStarted(uint256 _votingPollID) public view returns (bool) {
        return hasStarted[_votingPollID];
    }

    /*
        1. Retrieve all ACTIVE polls for VOTE PUBLISHER
        2. Retrieve all PENDING polls for VOTE PUBLISHER
        3. Retrieve all FINISHED polls for VOTE PUBLISHER
    */

    function getAllActivePollsVP() public view onlyVotePublisher returns(VotingPoll[] memory){
        uint256 activeCount = 0;

        for (uint256 i = 0; i < votingPollCounterID; i++) {
            if (votingPolls[i].votePublisher == msg.sender) {
                if(votingPolls[i].status == Status.Active){
                    activeCount++;
                }
            }
        }

        VotingPoll[] memory activePolls = new VotingPoll[](activeCount);

        uint256 index = 0;

        for (uint256 i = 0; i < votingPollCounterID; i++) {
            if (votingPolls[i].votePublisher == msg.sender) {
                if(votingPolls[i].status == Status.Active){
                    activePolls[index] = votingPolls[i];
                    index++;
                }
            }
        }

        return activePolls;
    }

    function getAllPendingPollsVP() public view onlyVotePublisher returns(VotingPoll[] memory){
        uint256 pendingCount = 0;

        for (uint256 i = 0; i < votingPollCounterID; i++) {
            if (votingPolls[i].votePublisher == msg.sender) {
                if(votingPolls[i].status == Status.Pending){
                    pendingCount++;
                }
            }
        }

        VotingPoll[] memory pendingPolls = new VotingPoll[](pendingCount);

        uint256 index = 0;

        for (uint256 i = 0; i < votingPollCounterID; i++) {
            if (votingPolls[i].votePublisher == msg.sender) {
                if(votingPolls[i].status == Status.Pending){
                    pendingPolls[index] = votingPolls[i];
                    index++;
                }
            }
        }

        return pendingPolls;
    }

    function getAllFinishedPollsVP() public view onlyVotePublisher returns(VotingPoll[] memory){
        uint256 finishedCount = 0;

        for (uint256 i = 0; i < votingPollCounterID; i++) {
            if (votingPolls[i].votePublisher == msg.sender) {
                if(votingPolls[i].status == Status.Finished){
                    finishedCount++;
                }
            }
        }

        VotingPoll[] memory finishedPolls = new VotingPoll[](finishedCount);

        uint256 index = 0;

        for (uint256 i = 0; i < votingPollCounterID; i++) {
            if (votingPolls[i].votePublisher == msg.sender) {
                if(votingPolls[i].status == Status.Finished){
                    finishedPolls[index] = votingPolls[i];
                    index++;
                }
            }
        }

        return finishedPolls;
    }

    //Function to see real time statistics of a voting poll of a vote publisher (finished and active)
    /*
        What do I need in this function:
            1. Get the voting poll
            2. Get all voting options for that voting poll
            3. Sum up all of the vote counts for the voting poll
            4. Since data cannot be float, we cannot do real statistics here but on the
               frontend, so send to the frontend  array of voting options
            5. On frontend side do the logic -> vote count of option / total vote count * 100 (rounded to 2) 
               = will get me desired percentage
    */
    function getStatistics(uint256 _votingPollID) public view isNotPending(_votingPollID) returns (VotingOption[] memory, uint256){
        uint256 totalVoteCount = 0;
        for(uint256 i = 0; i<votingOptionsByPoll[_votingPollID].length; i++){
            totalVoteCount += votingOptionsByPoll[_votingPollID][i].voteCount;
        }
        return (votingOptionsByPoll[_votingPollID], totalVoteCount);
    }

    function isPublisher(uint256 _votingPollID) public view returns (bool){
        //If the user is publisher of the poll, it will return true
        //Otherwise, false
        return votingPolls[_votingPollID].votePublisher == msg.sender;
    }

    /*
        1. Retrieve all ACTIVE - NON VOTED polls for VOTER which is not the 
            polls Vote Publisher
    */
    function getAllActivePollsVOTER() public view isVoter returns (VotingPoll[] memory){
        //Delete endVotingPolls() function from here
        uint256 activePolls = 0;
        for(uint256 i = 0; i<votingPollCounterID; i++){
            if(hasVoted[msg.sender][i] == false && isPublisher(i) == false && votingPolls[i].status == Status.Active){
                activePolls++;
            }
        }
        VotingPoll[] memory activeVotingPolls = new VotingPoll[](activePolls);
        uint256 index = 0;
        for(uint256 i = 0; i<votingPollCounterID; i++){
            if(hasVoted[msg.sender][i] == false && isPublisher(i) == false && votingPolls[i].status == Status.Active){
                activeVotingPolls[index++] = votingPolls[i];
            }
        }
        return activeVotingPolls;
    }

    function getAllVotedPollsVOTER() public view isVoter returns (VotingPoll[] memory) {
        uint256 activePolls = 0;
        for(uint256 i = 0; i<votingPollCounterID; i++){
            if(hasVoted[msg.sender][i] == true && votingPolls[i].status == Status.Active){
                activePolls++;
            }
        }
        VotingPoll[] memory activeVotingPolls = new VotingPoll[](activePolls);
        uint256 index = 0;
        for(uint256 i = 0; i<votingPollCounterID; i++){
            if(hasVoted[msg.sender][i] == true && votingPolls[i].status == Status.Active){
                activeVotingPolls[index++] = votingPolls[i];
            }
        }
        return activeVotingPolls;
    }

    function getAllFinishedPollsVOTER() public view isVoter returns (VotingPoll[] memory) {
        uint256 finishedPolls = 0;
        for(uint256 i = 0; i<votingPollCounterID; i++){
            if(votingPolls[i].status == Status.Finished){
                finishedPolls++;
            }
        }
        VotingPoll[] memory finishedVotingPolls = new VotingPoll[](finishedPolls);
        uint256 index = 0;
        for(uint256 i = 0; i<votingPollCounterID; i++){
            if(votingPolls[i].status == Status.Finished){
                finishedVotingPolls[index++] = votingPolls[i];
            }
        }
        return finishedVotingPolls;
    }

    function getAllVotingOptions(uint256 _votingPollID) public view returns(VotingOption[] memory) {
        return votingOptionsByPoll[_votingPollID];  
    }

    /*
        Function that will allow user to vote ONLY ONCE for a VOTING POLL
        for ONLY ONE VOTING OPTION
    */
    function vote(uint256 _votingPollID, uint256 _votingOptionID) public isVoter isActive(_votingPollID) hasNotVoted(_votingPollID) isNotPublisher(_votingPollID) hasNotFinished(_votingPollID){
        //Update that the user has voted
        //Emit that the user has voted
        //update the vote count for that voting poll
        /*
        if(block.timestamp >= votingPolls[_votingPollID].timeLeft){
            endVotingPoll(_votingPollID);
        }
        */
        require(votingPolls[_votingPollID].status == Status.Active, "Can't vote for a finished poll!");
        votingOptionsByPoll[_votingPollID][_votingOptionID].voteCount++;
        hasVoted[msg.sender][_votingPollID] = true;
        emit newVote(msg.sender, _votingPollID, block.timestamp);
    }
}