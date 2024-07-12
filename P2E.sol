// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Definition of a Quest structure
struct Quest {
    uint256 id;
    string description;
    uint256 tokenReward;
    uint256 participantCount;
    bool isActive;
    uint256 createdAt;
}

// Definition of a UserQuest structure
struct UserQuest {
    bool isCompleted;
    uint256 completionTime;
}

// Main contract SpacebirdzP2E
contract SpacebirdzP2E {
    using SafeERC20 for IERC20;

    bool locked; // Reentrancy guard
    address public admin; // Address of the contract admin
    uint256 public finalQuest; // Index of the final quest
    mapping(uint256 => Quest) public quests; // Mapping of quest IDs to Quest structures
    mapping(address => uint256) public pendingRewards; // Pending rewards for each user
    mapping(address => uint256) public pendingWithdrawal; // Pending withdrawal amounts for each user
    mapping(address => mapping(uint256 => UserQuest)) public userQuests; // Mapping of users to their completed quests
    mapping(uint256 => mapping(address => bool)) public participants; // Mapping of participants in each quest

    // Events emitted by the contract
    event NewQuestAdded(uint256 indexed questId, string description, uint256 tokenReward, bool isActive, uint256 createdAt);
    event WithdrawalRequested(address indexed user, uint256 amount);
    event WithdrawalApproved(address indexed user, uint256 amount);
    event WithdrawalRejected(address indexed user, uint256 amount);

    // Modifier: restricts access to only the contract admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    // Modifier: prevents reentrancy attacks
    modifier noReentrancy() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    // Constructor to set the contract admin
    constructor() {
        admin = msg.sender;
    }

    // Function to update the contract admin
    function updateAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "New admin address is not valid");
        admin = _newAdmin;
    }

    // Function to add or update a quest
    function addOrUpdateQuest(uint256 _id, string memory _description, uint256 _tokenReward, bool _isActive) public onlyAdmin {
        quests[_id] = Quest(_id, _description, _tokenReward, 0, _isActive, block.timestamp);
        uint256 limit = 5;
        for (uint256 i = 0; i < finalQuest; i++) {
            if ((quests[i].createdAt / 1 days) == (block.timestamp / 1 days)){
                limit = limit - 1;
                require(limit > 0, "Admin has created 5 quests today");
            }
        }
        
        if (_id > finalQuest) {
            finalQuest = _id;
        }

        emit NewQuestAdded(_id, _description, _tokenReward, _isActive, block.timestamp);
    }

    // Function to set the status of a quest (active or inactive)
    function setQuestStatus(uint256 _id, bool _isActive) public onlyAdmin {
        require(quests[_id].id != 0, "Quest not found");
        quests[_id].isActive = _isActive;
    }

    // Function for a user to participate in a quest
    function participateInQuest(uint256 _questId) public {
        require(quests[_questId].isActive, "Quest is not active");
        require(!participants[_questId][msg.sender], "You have already participated in this quest");
        
        participants[_questId][msg.sender] = true;
        quests[_questId].participantCount++;
        userQuests[msg.sender][_questId] = UserQuest(false, 0);
    }

    // Function for a user to complete a quest
    function completeQuest(uint256 _questId) public {
        require(userQuests[msg.sender][_questId].isCompleted == false, "Quest is already completed");
        userQuests[msg.sender][_questId].isCompleted = true;
        userQuests[msg.sender][_questId].completionTime = block.timestamp;
        pendingRewards[msg.sender] += quests[_questId].tokenReward;
    }

    // Function to get the total number of quests
    function getTotalQuest() public view returns(uint256) {
        uint questCount = 0;
        for (uint256 i = 1; i <= finalQuest; i++) {
            if (quests[i].createdAt != 0) {
                questCount++;
            }
        }
        return questCount;
    }

    // Function to get active quests
    function getActiveQuests() public view returns (Quest[] memory) {
        uint activeQuestCount = 0;
        for (uint256 i = 1; i <= finalQuest; i++) {
            if (quests[i].isActive && quests[i].createdAt != 0) {
                activeQuestCount++;
            }
        }
        Quest[] memory result = new Quest[](activeQuestCount);
        uint index = 0;
        for (uint256 i = 1; i <= finalQuest; i++) {
            if (quests[i].isActive && quests[i].createdAt != 0) {
                result[index] = quests[i];
                index++;
            }
        }
        return result;
    }

    // Function to get inactive quests
    function getInactiveQuests() public view returns (Quest[] memory) {
        uint inactiveQuestCount = 0;
        for (uint256 i = 1; i <= finalQuest; i++) {
            if (!quests[i].isActive && quests[i].createdAt != 0) {
                inactiveQuestCount++;
            }
        }
        Quest[] memory result = new Quest[](inactiveQuestCount);
        uint index = 0;
        for (uint256 i = 1; i <= finalQuest; i++) {
            if (!quests[i].isActive && quests[i].createdAt != 0) {
                result[index] = quests[i];
                index++;
            }
        }
        return result;
    }

    // Function for a user to request withdrawal of pending rewards
    function requestWithdrawal() public noReentrancy {
        uint256 rewardAmount = pendingRewards[msg.sender];
        require(rewardAmount > 0, "No rewards to withdraw");
        pendingRewards[msg.sender] = 0;
        pendingWithdrawal[msg.sender] += rewardAmount;

        emit WithdrawalRequested(msg.sender, rewardAmount);
    }

    // Function for the admin to approve withdrawal requests
    function approveWithdrawal(address _user, address _tokenContract) public onlyAdmin {
        require(IERC20(_tokenContract).balanceOf(address(this)) > pendingWithdrawal[_user], "Not enough token balance");
        IERC20(_tokenContract).safeTransfer(_user, pendingWithdrawal[_user]);
        
        emit WithdrawalApproved(_user, pendingWithdrawal[_user]);
    }

    // Function for the admin to reject withdrawal requests
    function rejectWithdrawal(address _user) public onlyAdmin {
        uint256 amount = pendingWithdrawal[_user];
        require(amount > 0, "No withdrawal to reject");
        
        pendingWithdrawal[_user] = 0;
        pendingRewards[_user] += amount;
        emit WithdrawalRejected(_user, amount);
    }
}
