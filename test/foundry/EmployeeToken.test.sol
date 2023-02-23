//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { EmployeeToken } from '../../contracts/EmployeeToken.sol';
import { MockERC20, MockUser } from './utils/Utils.sol';

contract EmployeeTokenTest is Test {
  MockERC20 bluToken;
  EmployeeToken eBLU;

  address treasury;
  address sheng;
  address stephon;

  function setUp() public {
    // prepare wallet addresses
    MockUser mUsers = new MockUser();
    treasury = mUsers.getNextUserAddress();
    sheng = mUsers.getNextUserAddress();
    stephon = mUsers.getNextUserAddress();

    // setup employeeToken contract
    bluToken = new MockERC20('blujay', 'BLU');
    eBLU = new EmployeeToken(address(bluToken), treasury);

    // issue some eBLU for testing
    address[] memory users = new address[](2);
    users[0] = sheng;
    users[1] = stephon;
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 10_000e18;
    amounts[1] = 10_000e18;
    eBLU.issue(users, amounts);
  }

  function test_issue() public {
    console.log('test_issue');

    // reverted when params length are not consist
    address[] memory users = new address[](2);
    uint256[] memory amounts = new uint256[](1);

    users[0] = sheng;
    users[1] = stephon;

    vm.expectRevert(abi.encodePacked('Invalid issue params'));
    eBLU.issue(users, amounts);

    // reverted when invalid param is being used
    amounts = new uint256[](2);

    vm.expectRevert(abi.encodePacked('Invalid issue param'));
    eBLU.issue(users, amounts);
  }

  function test_pause() public {
    console.log('test_pause');

    // pause from not-owner
    vm.startPrank(stephon);
    vm.expectRevert(abi.encodePacked('Ownable: caller is not the owner'));
    eBLU.setPause(false);
    vm.stopPrank();

    // unpause when not pasued
    vm.expectRevert(abi.encodePacked('Not Paused'));
    eBLU.setPause(false);

    // pause when paused
    eBLU.setPause(true);
    vm.expectRevert(abi.encodePacked('Already Paused'));
    eBLU.setPause(true);
  }

  function test_treasury() public {
    console.log('test_treasury');

    // from not-owner
    vm.startPrank(stephon);
    vm.expectRevert(abi.encodePacked('Ownable: caller is not the owner'));
    eBLU.setTreasury(stephon);
    vm.stopPrank();

    // invalid param
    vm.expectRevert(abi.encodePacked('Invalid treasury address'));
    eBLU.setTreasury(address(0));

    // previous treasury
    vm.expectRevert(abi.encodePacked('Invalid treasury address'));
    eBLU.setTreasury(treasury);
  }

  function test_transfer(uint256 amount) public {
    console.log('test_transfer');

    vm.assume(amount > 0 && amount < 100_000e18);

    uint256 stephon_original_eBLU_balance = eBLU.balanceOf(stephon);
    uint256 sheng_original_eBLU_balance = eBLU.balanceOf(sheng);
    uint256 stephon_original_unlocked_blanace = eBLU.unlockedBalance(stephon);

    // transfer exceeding unlock balance
    vm.startPrank(stephon);
    vm.expectRevert(abi.encodePacked('Exceed avaialable unlock balance'));
    eBLU.transfer(sheng, amount);
    vm.stopPrank();

    // reached to target supply
    bluToken.mint(treasury, 100_00000e18);
    uint256 unlockableBalance = eBLU.unlockableBalance(stephon);
    vm.assume(amount < unlockableBalance);

    // transfer when paused
    eBLU.setPause(true);
    vm.startPrank(stephon);
    vm.expectRevert(abi.encodePacked('Paused'));
    eBLU.transfer(sheng, amount);
    vm.stopPrank();

    // transfer success
    eBLU.setPause(false);
    vm.startPrank(stephon);
    eBLU.transfer(sheng, amount);
    vm.stopPrank();

    assertEq(eBLU.balanceOf(stephon), stephon_original_eBLU_balance - amount);
    assertEq(eBLU.balanceOf(sheng), sheng_original_eBLU_balance + amount);
    assertEq(
      eBLU.unlockedBalance(stephon),
      stephon_original_unlocked_blanace + amount
    );
  }

  function test_unlockableBalance() public {
    console.log('test_unlockableBalance');

    // when no BLU tokens
    assertEq(eBLU.unlockableBalance(stephon), 0);

    // when 1M BLU minted
    bluToken.mint(treasury, 1_000000e18);
    assertEq(eBLU.unlockableBalance(stephon), 100e18);

    // when 10M BLU minted
    bluToken.mint(treasury, 9_000000e18);
    assertEq(eBLU.unlockableBalance(stephon), 1000e18);

    // when 100M BLU minted
    bluToken.mint(treasury, 90_000000e18);
    assertEq(eBLU.unlockableBalance(stephon), 10000e18);
  }

  function test_redeem(uint256 amount) public {
    console.log('test_unlockableBalance');

    assertEq(bluToken.balanceOf(stephon), 0);
    assertEq(bluToken.balanceOf(sheng), 0);
    uint256 stephon_original_eBLU_balance = eBLU.balanceOf(stephon);
    uint256 sheng_original_eBLU_balance = eBLU.balanceOf(sheng);

    vm.startPrank(stephon);

    bluToken.mint(treasury, 10_000000e18);
    vm.stopPrank();
    vm.startPrank(treasury);
    bluToken.approve(address(eBLU), 10_000000e18);
    vm.stopPrank();

    uint256 unlockableBalance = eBLU.unlockableBalance(stephon);
    vm.assume(amount > 0 && amount < unlockableBalance);
    vm.startPrank(stephon);

    // when redeem exceeding balance
    vm.expectRevert(abi.encodePacked('Exceed redeemable balance'));
    eBLU.redeem(sheng, unlockableBalance * 2);

    // redeem when paused
    vm.stopPrank();
    eBLU.setPause(true);
    vm.startPrank(stephon);
    vm.expectRevert(abi.encodePacked('Paused'));
    eBLU.redeem(sheng, amount);

    // redeem success
    vm.stopPrank();
    eBLU.setPause(false);
    vm.startPrank(stephon);
    eBLU.redeem(sheng, amount);

    assertEq(bluToken.balanceOf(stephon), 0);
    assertEq(eBLU.balanceOf(stephon), stephon_original_eBLU_balance - amount);
    assertEq(bluToken.balanceOf(sheng), amount);
    assertEq(eBLU.balanceOf(sheng), sheng_original_eBLU_balance);
  }
}
