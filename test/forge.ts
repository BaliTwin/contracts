import { expect } from 'chai'
import { ethers } from 'hardhat'
import { contracts } from './fixtures'

describe.only('Forge', () => {
	describe('Crafting', () => {
		it('Should mint tokens', async () => {
			const [, user, wallet] = await ethers.getSigners()

			const { Collection1155, Collection721 } = await contracts()
			const BaliTwinForge = await ethers.getContractFactory('BaliTwinForge')
			const Forge = await BaliTwinForge.deploy()

			await Promise.all([
				Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), Forge.address),
				Collection721.grantRole(await Collection721.AUTHOR_ROLE(), Forge.address),
				await Collection1155.mintBatch(user.address, [1, 2], [1, 1], []),
				await Collection1155.connect(user).setApprovalForAll(Forge.address, true)
			])
			
			const value = ethers.utils.parseEther('1')

			await Forge.addRecipe(
				{
					token: Collection1155.address, 
					ids: [1, 2], 
					amounts: [1, 1]
				},
				{
					token: Collection721.address,
					ids: [1],
					amounts: [1]
				},
				{
					token: ethers.constants.AddressZero,
					ids: [0],
					amounts: [value]
				},
				1
			).then(tx => tx.wait())
			
			const [id] = await Forge.getActiveRecipes()
			
			await Forge.connect(user).craft(id, { value })

			// check if user has the crafted token
			expect(await Collection721.balanceOf(user.address)).to.equal(1)
			
			// check if user has no the required tokens
			expect(
				await Collection1155.balanceOfBatch([user.address, user.address], [1, 2])
			).to.deep.equal([0, 0])

			// check if required tokens are burned 
			expect(await Collection1155.totalSupply(1)).to.equal(0)
			expect(await Collection1155.totalSupply(2)).to.equal(0)

			// check if the recipe is inactive
			await expect(Forge.craft(id)).to.be.revertedWith('BaliTwinForge: recipe limit reached')

			const balance = await ethers.provider.getBalance(wallet.address)
			await Forge.withdraw(ethers.constants.AddressZero, value, wallet.address)

			expect(await ethers.provider.getBalance(wallet.address)).to.equal(balance.add(value))
		})
	})	
})