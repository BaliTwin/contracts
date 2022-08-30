import { expect } from 'chai'
import { ethers } from 'hardhat'
import { 
	contracts, accessError, randomInt,
	ipfsCID, nullData,
	META_URI, NAME_1155, SYMBOL_1155
} from './fixtures'

describe('Collection1155', () => {
	describe('Contract data', () => {
		it('name()', async () => {
			const { Collection1155 } = await contracts()
			expect(await Collection1155.name()).to.equal(NAME_1155)
		})
		
		it('symbol()', async () => {
			const { Collection1155 } = await contracts()
			expect(await Collection1155.symbol()).to.equal(SYMBOL_1155)
		})
		
		it('contractURI(): Contract meta', async () => {
			const { Collection1155 } = await contracts()
			expect(await Collection1155.contractURI()).to.equal(META_URI)
		})
	})

	describe('Minting', () => {
		it('mint(): Mint only for granted author', async () => {
			const { Collection1155 } = await contracts() 
			const [, user] = await ethers.getSigners()
			
			await expect(
				Collection1155.connect(user).mint(user.address, ipfsCID(), 1, nullData)
			).to.revertedWith(
				accessError(await Collection1155.AUTHOR_ROLE(), user.address)
			)
		})
				
			
		it('mint(), burn(), grantRole(): Single mint & burn', async () => {
			const [, author] = await ethers.getSigners()
			const { Collection1155 } = await contracts()

			const id = await ipfsCID()
			const total = 10
			const toBurn = randomInt()

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
			await Collection1155.connect(author).mint(
				author.address, id, total, nullData
			).then(tx => tx.wait())

			expect(await Collection1155.totalSupply(id)).to.equal(total)

			// Burning
			await Collection1155.connect(author).burn(author.address, id, toBurn)
			expect(await Collection1155.totalSupply(id)).to.equal(total - toBurn)
		})

		it('mintBatch(), burnBatch(): Batch mint & burn', async () => {
			const [, author] = await ethers.getSigners()
			const { Collection1155 } = await contracts()

			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => randomInt() || 1)

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
			await Collection1155.connect(author).mintBatch(
				author.address, ids, amounts, nullData
			).then(tx => tx.wait())

			for (let i = 0; i < ids.length; i++)
				expect(await Collection1155.totalSupply(ids[i])).to.be.equal(amounts[i])
			
			// Burning
			await Collection1155.connect(author).burnBatch(author.address, ids, amounts)
			for (let i = 0; i < ids.length; i++)
				expect(await Collection1155.totalSupply(ids[i])).to.be.equal(0)
		})	
	})

	describe('Reading data', () => {
		it('tokens(): List of all minted tokens ID', async () => {
			const [, author] = await ethers.getSigners()
			const { Collection1155 } = await contracts()
			
			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => randomInt() || 1)
			
			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
			await Collection1155.connect(author).mintBatch(
				author.address, ids, amounts, nullData
			).then(tx => tx.wait())
				
			expect(await Collection1155.tokens()).to.deep.equal(ids)
		})

		it('tokensOfOwner(): List of token ids which owned by provided address.', async () => {
			const [, author] = await ethers.getSigners()
			const { Collection1155 } = await contracts()

			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => randomInt() || 1)

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
			await Collection1155.connect(author).mintBatch(
				author.address, ids, amounts, nullData
			).then(tx => tx.wait())
			
			expect(await Collection1155.tokensOfOwner(author.address)).to.deep.equal(ids)
		})

		it('authorOf(), mintedBy(): Authorship', async () => {
			const { Collection1155 } = await contracts() 
			const [author, user] = await ethers.getSigners()

			await Collection1155.grantRole(
				await Collection1155.AUTHOR_ROLE(), author.address
			)
			
			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => randomInt() || 1)

			await Collection1155.mintBatch(
				user.address, ids, amounts, nullData
			).then(tx => tx.wait())

			expect(await Collection1155.authorOf(ids[0])).to.equal(author.address)
			expect(await Collection1155.mintedBy(author.address)).to.deep.equal(ids)
		})

		it('uri(): Token URI', async () => {
			const [signer] = await ethers.getSigners()
			const { Collection1155 } = await contracts()
			const id = await ipfsCID()

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), signer.address)
			await Collection1155.mint(signer.address, id, 1, nullData).then(tx => tx.wait())

			await expect(Collection1155.uri(await ipfsCID())).rejectedWith(
				'Token with provided id is not exists'
			)
			
			const uri = await Collection1155.uri(id)
			expect(uri).to.equal(`ipfs://f0${id.slice(2).toUpperCase()}`)
		})
	})
})