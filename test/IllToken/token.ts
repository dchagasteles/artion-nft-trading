import { expect } from 'chai';
import { ethers } from 'hardhat';

import {
  runTestSuite,
  TestVars,
  lastBlockNumber,
  backupTransferWithSignedMessage,
} from './helpers';

runTestSuite('IllToken', (vars: TestVars) => {
  it('token data', async () => {
    const { IllToken } = vars;
    expect(await IllToken.name()).to.equal('Ill Token');
    expect(await IllToken.symbol()).to.equal('ILLT');
    expect(await IllToken.decimals()).to.be.eq(18);
  });

  describe('set backup', async () => {
    it('reverted case', async () => {
      const {
        accounts: [admin, bob, backup],
        IllToken,
      } = vars;

      await expect(
        IllToken.registerBackupAddress(ethers.constants.AddressZero)
      ).to.be.revertedWith('Invalid backup address');

      await expect(
        IllToken.connect(bob.signer).registerBackupAddress(backup.address)
      ).to.be.revertedWith('Not token holder');
    });

    it('success case', async () => {
      const {
        accounts: [admin, bob, backup],
        IllToken,
      } = vars;

      await IllToken.registerBackupAddress(backup.address);

      expect(await IllToken.backupAddress(admin.address)).to.be.eq(
        backup.address
      );
    });
  });

  describe('transfer to backup without signed message', async () => {
    it('reverted case', async () => {
      const {
        accounts: [admin, bob, backup],
        IllToken,
      } = vars;

      await expect(
        IllToken.connect(bob.signer).transferToBackup(100)
      ).to.be.revertedWith('Exceeds user balance');

      await expect(IllToken.transferToBackup(100)).to.be.revertedWith(
        'Backup address is not registered'
      );
    });

    it('success case', async () => {
      const {
        accounts: [admin, bob, backup],
        IllToken,
      } = vars;

      await IllToken.registerBackupAddress(backup.address);
      expect(await IllToken.transferToBackup(1000))
        .to.emit(IllToken, 'TransferredToBackup')
        .withArgs(admin.address, backup.address, 1000, await lastBlockNumber());
    });
  });

  describe('transfer to backup with signed message', async () => {
    it('success case', async () => {
      const {
        accounts: [admin, bob, initiator, backup],
        IllToken,
      } = vars;

      // transfer IllTokens to bob for testing
      await IllToken.transfer(bob.address, 1000);

      // register bob's backup address
      await IllToken.connect(bob.signer).registerBackupAddress(backup.address);

      // do backup transfer with signed message
      await backupTransferWithSignedMessage(IllToken, bob, initiator, 1000);

      // check if bob balance is 0
      expect(await IllToken.balanceOf(bob.address)).to.be.eq(0);

      // check if backup balance is 1000
      expect(await IllToken.balanceOf(backup.address)).to.be.eq(1000);
    });

    it('reverted cases', async () => {
      const {
        accounts: [admin, bob, initiator, backup],
        IllToken,
      } = vars;

      await expect(
        backupTransferWithSignedMessage(IllToken, admin, admin, 1000)
      ).to.be.revertedWith('Not delegator');

      await expect(
        backupTransferWithSignedMessage(IllToken, admin, initiator, 1000)
      ).to.be.revertedWith('Backup address is not registered');

      await IllToken.registerBackupAddress(backup.address);

      await expect(
        IllToken.connect(
          initiator.signer
        ).transferTokensToBackupWithSignedMessage(
          admin.address,
          1000,
          1,
          ethers.utils.formatBytes32String('random'),
          ethers.utils.formatBytes32String('random')
        )
      ).to.be.revertedWith('INVALID_SIGNATURE');
    });
  });
});
