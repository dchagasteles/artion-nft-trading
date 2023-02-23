//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/// @title EmployeeToken
contract EmployeeToken is ERC20, Ownable {
  using SafeERC20 for IERC20;

  uint256 public constant BASE = 1e18;

  /// @notice address of company treasury where we will retrieve BLU tokens from
  address public treasury;

  /// @notice address of the BLU token (underlying asset)
  IERC20 public immutable bluToken;

  /// @notice amount of unlocked employeeToken for user
  mapping(address => uint256) public unlockedBalance;

  /// @notice BLU token supply target for whole unlock
  uint256 public constant TARGET_SUPPlY = 100000000e18; // 100M

  /// @notice pause/unpause main actions
  bool private _paused;

  /// @notice emitted when pause status is updated
  event SetPaused(bool status);

  /// @notice emitted when treasury address is updated
  event TreasurySet(address treasury);

  /// @notice emitted when employee redeems
  event Redeemed(
    address indexed user,
    address indexed recipient,
    uint256 amount,
    uint256 timestamp
  );

  /// @notice initialize EmployeeToken contract
  /// @param _bluToken address of the BLU token
  /// @param _treasury address of the treasury
  constructor(
    address _bluToken,
    address _treasury
  ) ERC20('Bluejay Employ Token', 'eBLU') {
    require(_bluToken != address(0), 'Invalid BLU token');
    require(_treasury != address(0), 'Invalid treasury address');

    bluToken = IERC20(_bluToken);
    treasury = _treasury;

    _paused = false;
  }

  /// @notice update contract status
  /// @param _status of the contract pause
  function setPause(bool _status) external onlyOwner {
    if (_status) {
      require(!_paused, 'Already Paused');
    } else {
      require(_paused, 'Not Paused');
    }
    _paused = _status;
    emit SetPaused(_paused);
  }

  /// @notice update treasury address
  /// @param _treasury address of the new treasury wallet
  function setTreasury(address _treasury) external onlyOwner {
    require(
      treasury != _treasury && _treasury != address(0),
      'Invalid treasury address'
    );

    treasury = _treasury;
    emit TreasurySet(treasury);
  }

  /// @notice owner will issue EBLU tokens to employess
  /// @param users array of employess' address
  /// @param amounts array of EBLU tokens to issue
  function issue(
    address[] memory users,
    uint256[] memory amounts
  ) external onlyOwner {
    require(!_paused, 'Paused');
    require(
      users.length > 0 && users.length == amounts.length,
      'Invalid issue params'
    );

    for (uint256 i = 0; i < users.length; i++) {
      require(users[0] != address(0) && amounts[0] > 0, 'Invalid issue param');

      _mint(users[i], amounts[i]);
    }
  }

  /// @notice get unlockable EBLU token balance
  /// @param user address of user wallet
  function unlockableBalance(address user) public view returns (uint256) {
    uint256 redeemRate;

    uint256 currentBLUSupply = bluToken.totalSupply();
    if (currentBLUSupply < TARGET_SUPPlY) {
      redeemRate = (currentBLUSupply * BASE) / TARGET_SUPPlY;
    } else {
      redeemRate = BASE;
    }

    return (balanceOf(user) * redeemRate) / BASE - unlockedBalance[user];
  }

  /// @notice redeem BLU tokens
  /// @param recipient address of user wallet who will get redeemed BLU tokens
  /// @param amount of eBLU tokens to redeem
  function redeem(address recipient, uint256 amount) external {
    require(!_paused, 'Paused');

    uint256 redeemBalance = amount == 0 ? balanceOf(msg.sender) : amount;

    require(redeemBalance > 0, 'No redeemable balance');
    require(
      redeemBalance <= unlockableBalance(msg.sender),
      'Exceed redeemable balance'
    );

    // burn eBLU token
    _burn(msg.sender, redeemBalance);

    // increase unlocked balance
    unlockedBalance[msg.sender] += redeemBalance;

    // transfer BLU tokens to recipient
    bluToken.safeTransferFrom(treasury, recipient, redeemBalance);

    emit Redeemed(msg.sender, recipient, amount, block.timestamp);
  }

  /// @notice some validations when token transfer
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    if (from != address(0) && to != address(0)) {
      // make sure to transfer only unlockable balance
      require(
        unlockableBalance(from) >= amount,
        'Exceed avaialable unlock balance'
      );

      // make sure to transfer when transfer tokens
      require(!_paused, 'Paused');

      // increase unlocked balance after transfer
      unlockedBalance[from] += amount;
    }
  }
}
