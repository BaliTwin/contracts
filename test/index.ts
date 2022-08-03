import { expect } from 'chai'
import { ethers } from 'hardhat'
import { 
	contracts, accessError, usdt,
	ipfsCID, randomPrice, invoice, nullData,
	list721, list1155, listBatch1155,
	META_URI, NAME_721, NAME_1155, SYMBOL_721, SYMBOL_1155
} from './fixtures'

const { defaultAbiCoder : AbiCoder } = ethers.utils
	
describe('Collection', () => {

	describe('721', () => {
		it('name()', async () => {
			const { Collection721 } = await contracts()
			expect(await Collection721.name()).to.equal(NAME_721)
		})
		it('symbol()', async () => {
			const { Collection721 } = await contracts()
			expect(await Collection721.symbol()).to.equal(SYMBOL_721)
		})
		it('contractURI(): Contract meta', async () => {
			const { Collection721 } = await contracts()
			expect(await Collection721.contractURI()).to.equal(META_URI)
		})

		it('mint(): Mint only for granted author', async () => {
			const { Collection721 } = await contracts() 
			const [author, user] = await ethers.getSigners()

			await expect(
				Collection721.mint(user.address, ipfsCID(), nullData)
			).to.revertedWith(
				accessError(await Collection721.AUTHOR_ROLE(), author.address)
			)
		})

		it('grantRole(), mint(), burn(): Mint & burn', async () => {
			const { Collection721 } = await contracts() 
			const [author] = await ethers.getSigners()
			const id = 0

			await Collection721.grantRole(await Collection721.AUTHOR_ROLE(), author.address)
			
			await Collection721.mint(author.address, ipfsCID(), nullData).then(tx => tx.wait())

			expect(await Collection721.totalSupply()).to.equal(1)
			expect(await Collection721.ownerOf(id)).to.equal(author.address)

			await Collection721.burn(id)
			expect(await Collection721.totalSupply()).to.equal(0)
		})

		it('tokensOfOwner(): Owned tokens', async () => {
			const { Collection721 } = await contracts() 
			const [author, ...users] = await ethers.getSigners()

			await Collection721.grantRole(
				await Collection721.AUTHOR_ROLE(), author.address
			)
			
			const uris = await Promise.all(Array(5).fill(0).map(ipfsCID))
			
			for (let i = 0; i < uris.length; i++) {
				await Collection721
					.mint(users[i].address, uris[i], nullData)
					.then(tx => tx.wait()).then(tx => tx.events[0].args.tokenId)
			}

			for (let i = 0; i < uris.length; i++) {
				expect(await Collection721.tokensOfOwner(users[i].address)).to.deep.equal([i])
			}
		})
			
		it('authorOf(), mintedBy(): Authorship', async () => {
			const { Collection721 } = await contracts() 
			const [author, user] = await ethers.getSigners()

			await Collection721.grantRole(
				await Collection721.AUTHOR_ROLE(), author.address
			)
			
			const uris = await Promise.all(Array(5).fill(0).map(ipfsCID))

			const ids = await Promise.all(uris.map(id => 
				Collection721
					.mint(user.address, ipfsCID(), nullData)
					.then(tx => tx.wait()).then(tx => tx.events[0].args.tokenId)
			))

			expect(await Collection721.authorOf(ids[0])).to.equal(author.address)
			expect(await Collection721.mintedBy(author.address)).to.deep.equal(ids)
		})

		it('Token URI is unique', async () => {
			const [author, user] = await ethers.getSigners()
			const { Collection721 } = await contracts() 

			const uri = ipfsCID()

			await Collection721.grantRole(
				await Collection721.AUTHOR_ROLE(), author.address
			)
			await Collection721.mint(user.address, uri, nullData)
			await expect(
				Collection721.mint(user.address, uri, nullData)
			).to.be.revertedWith('Provided URI already minted')
		})

	})

	// ft / nft
	describe('1155', () => {

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

		it('mint(): Mint only for granted author', async () => {
			const { Collection1155 } = await contracts() 
			const [author, user] = await ethers.getSigners()

			await expect(
				Collection1155.mint(user.address, ipfsCID(), 1, nullData)
			).to.revertedWith(
				accessError(await Collection1155.AUTHOR_ROLE(), author.address)
			)
		})

		it('mint(), burn(), grantRole(): Single mint & burn', async () => {
			const [user] = await ethers.getSigners()
			const { Collection1155 } = await contracts()
			const id = await ipfsCID()
			const total = 10
			const toBurn = 3

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), user.address)
			await Collection1155.mint(user.address, id, total, nullData).then(tx => tx.wait())

			expect(await Collection1155.totalSupply(id)).to.equal(total)

			// Burning
			await Collection1155.burn(user.address, id, toBurn)
			expect(await Collection1155.totalSupply(id)).to.equal(total - toBurn)
		})

		it('mintBathc(), burnBatch(): Batch mint & burn', async () => {
			const [user] = await ethers.getSigners()
			const { Collection1155 } = await contracts()

			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => (Math.random() * 10 >> 0) || 1)

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), user.address)
			await Collection1155.mintBatch(
				user.address, ids, amounts, nullData
			).then(tx => tx.wait())

			for (let i = 0; i < ids.length; i++)
				expect(await Collection1155.totalSupply(ids[i])).to.be.equal(amounts[i])
			
			// Burning
			await Collection1155.burnBatch(user.address, ids, amounts)
			for (let i = 0; i < ids.length; i++)
				expect(await Collection1155.totalSupply(ids[i])).to.be.equal(0)
		})

		it('tokens(): Minted tokens', async () => {
			const [user] = await ethers.getSigners()
			const { Collection1155 } = await contracts()

			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => (Math.random() * 10 >> 0) || 1)

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), user.address)
			await Collection1155.mintBatch(
				user.address, ids, amounts, nullData
			).then(tx => tx.wait())
			
			expect(await Collection1155.tokens()).to.deep.equal(ids)
		})

		it('tokensOfOwner(): Owned tokens', async () => {
			const [user] = await ethers.getSigners()
			const { Collection1155 } = await contracts()

			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => (Math.random() * 10 >> 0) || 1)

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), user.address)
			await Collection1155.mintBatch(
				user.address, ids, amounts, nullData
			).then(tx => tx.wait())
			
			expect(await Collection1155.tokensOfOwner(user.address)).to.deep.equal(ids)
		})

		it('authorOf(), mintedBy(): Authorship', async () => {
			const { Collection1155 } = await contracts() 
			const [author, user] = await ethers.getSigners()

			await Collection1155.grantRole(
				await Collection1155.AUTHOR_ROLE(), author.address
			)
			
			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => (Math.random() * 10 >> 0) || 1)

			await Collection1155.mintBatch(
				user.address, ids, amounts, nullData
			).then(tx => tx.wait())

			expect(await Collection1155.authorOf(ids[0])).to.equal(author.address)
			expect(await Collection1155.mintedBy(author.address)).to.deep.equal(ids)
		})

		it('uri(): Token URI', async () => {
			const [signer] = await ethers.getSigners()
			const { Collection1155 } = await contracts()
			const id = await ipfsCID() // 0x072b479c08a90414db5f8b2bd684e4323d7d13dd Failed case

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), signer.address)
			await Collection1155.mint(signer.address, id, 1, nullData).then(tx => tx.wait())
			
			const uri = await Collection1155.uri(id)
			expect(uri).to.equal(`ipfs://f0${id.slice(2).toUpperCase()}`)
		})
	})
})


// Market
// -
// Drop event

describe('Market', () => {
	describe('Listing', () => {
		it('Invoice validation', async () => {
			const [author] = await ethers.getSigners()
			const { Market, Collection721 } = await contracts()

			await Collection721.grantRole(await Collection721.AUTHOR_ROLE(), author.address)
			await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection721.address)

			// Min price
			await expect(
				Collection721.mint(Market.address, ipfsCID(), invoice(0))
			).to.revertedWith('Price must be greater than minimal price')
		})
		
		it('Only for verified collections', async () => {
			const [author] = await ethers.getSigners()
			const { Market, Collection721 } = await contracts()

			await Collection721.grantRole(await Collection721.AUTHOR_ROLE(), author.address)	
			await expect(
				Collection721.mint(Market.address, ipfsCID(), invoice())
			).to.revertedWith(
				accessError(await Market.VERIFIED_COLLECTION(), Collection721.address)
			)
		})

		it('Unlist', async () => {
			const { Market, author, Collection1155, id } = await list1155({})
			const [itemId] = await Market.items()

			expect(await Collection1155.balanceOf(author.address, id)).to.equal(0)
			expect(await Collection1155.balanceOf(Market.address, id)).to.equal(1)
			
			await Market.connect(author).unlist(itemId, 1)

			expect(await Collection1155.balanceOf(author.address, id)).to.equal(1)
			expect(await Collection1155.balanceOf(Market.address, id)).to.equal(0)
		})

		describe('721', () => {
			it('Listing by mint', async () => {
				const { 
					Market, Collection721,
					id, price, author 
				} = await list721({})
				const [listed] = await Market.items()

				expect(listed.id).to.equals(id)
				expect(listed.collection).to.equals(Collection721.address)
				expect(listed.price).to.equals(price)
				expect(listed.author).to.equals(author.address)
				expect(listed.seller).to.equals(author.address)
			})

			it('Listing by transfer', async () => {
				const [, author, seller] = await ethers.getSigners()
				const { Market, Collection721 } = await contracts()
	
				await Collection721.grantRole(await Collection721.AUTHOR_ROLE(), author.address)
				await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection721.address)
				
				const price = randomPrice()
				const id = await Collection721
					.connect(author)
					.mint(seller.address, ipfsCID(), nullData)
					.then(tx => tx.wait())
					.then(tx => tx.events[0].args.tokenId)

				await Collection721
					.connect(seller)
					['safeTransferFrom(address,address,uint256,bytes)']
					(seller.address, Market.address, id, invoice(price))
				
				const [listed] = await Market.items()

				expect(listed.id).to.equals(id)
				expect(listed.collection).to.equals(Collection721.address)
				expect(listed.price).to.equals(price)
				expect(listed.author).to.equals(author.address)
				expect(listed.seller).to.equals(seller.address)
			})
		})

		describe('1155', () => {
			it('Listing by single mint', async () => {
				const { 
					Market, Collection1155,
					id, price, author 
				} = await list1155({})
				
				const [listed] = await Market.items()

				expect(listed.id).to.equals(id)
				expect(listed.collection).to.equals(Collection1155.address)
				expect(listed.price).to.equals(price)
				expect(listed.author).to.equals(author.address)
				expect(listed.seller).to.equals(author.address)

				await Collection1155
					.connect(author)
					.mint(Market.address, id, 1, invoice())
					.then(tx => tx.wait())

				// No dupblicates on refill
				expect((await Market.items()).length).to.equal(1)
			})

			it('Listing by single transfer', async () => {
				const [, author, seller] = await ethers.getSigners()
				const { Market, Collection1155 } = await contracts()

				await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
				await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection1155.address)

				const price = randomPrice()
				const id = ipfsCID()
		
				await Collection1155
					.connect(author)
					.mint(seller.address, id, 1, nullData)
					.then(tx => tx.wait())

				await Collection1155
					.connect(seller)
					['safeTransferFrom(address,address,uint256,uint256,bytes)']
					(seller.address, Market.address, id, 1, invoice(price))

				const [listed] = await Market.items()

				expect(listed.id).to.equals(id)
				expect(listed.collection).to.equals(Collection1155.address)
				expect(listed.price).to.equals(price)
				expect(listed.author).to.equals(author.address)
				expect(listed.seller).to.equals(seller.address)
			})

			it('Listing by mint of 1155 batch', async () => {
				const { 
					Market, Collection1155,
					author, items
				} = await listBatch1155({})

				const listed = await Market.items()
				expect(listed.length).to.equal(items.length)

				for (let i = 0; i < items.length; i++) {
					expect(listed[i].id).to.equals(items[i].id)
					expect(listed[i].collection).to.equals(Collection1155.address)
					expect(listed[i].price).to.equals(items[i].price)
					expect(listed[i].author).to.equals(author.address)
					expect(listed[i].seller).to.equals(author.address)
				}
			})

			it('Listing by transfer batch of 1155', async () => {
				const [, author, seller] = await ethers.getSigners()
				const { Market, Collection1155 } = await contracts()

				await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
				await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection1155.address)

				const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
				const amounts = ids.map(() => (Math.random() * 10 >> 0) || 1)
				const prices = ids.map(randomPrice)
				const datas = AbiCoder.encode(
					['bytes[]'], [prices.map(price => invoice(price))]
				)

				await Collection1155.connect(author).mintBatch(seller.address, ids, amounts, datas)
				await Collection1155
					.connect(seller)
					['safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)']
					(seller.address, Market.address, ids, amounts, datas)

				const items = await Market.items()
				expect(items.length).to.equal(5)

				for (let i = 0; i < items.length; i++) {
					expect(items[i].id).to.equals(ids[i])
					expect(items[i].collection).to.equals(Collection1155.address)
					expect(items[i].price).to.equals(prices[i])
					expect(items[i].author).to.equals(author.address)
					expect(items[i].seller).to.equals(seller.address)
				}
			})
		})
	})

	describe('Purchase', () => {
		it('Item transfer after purchase', async () => {
			const { USDT, wallets, Market } = await contracts()
			
			const { Collection1155 } = await listBatch1155({ Market })
			const [id] = await Market.items()

			const item = await Market.item(id)
			const buyer = wallets[2]

			const amount = await Collection1155.balanceOf(Market.address, item.id)
			const balance = await USDT.balanceOf(buyer.address)
			
			expect(await USDT.balanceOf(Market.address)).to.equal(0)
			expect(await Collection1155.balanceOf(buyer.address, item.id)).to.equal(0)

			await USDT.connect(buyer).approve(Market.address, item.price * amount)
			await Market.connect(buyer).buy(id, amount)

			expect(await USDT.balanceOf(Market.address)).to.equal(item.price * amount)
			expect(await USDT.balanceOf(buyer.address)).to.equal(balance - item.price * amount)
			expect(await Collection1155.balanceOf(Market.address, item.id)).to.equal(0)
			expect(await Collection1155.balanceOf(buyer.address, item.id)).to.equal(amount)
		})

		describe('Fees', () => {
			it('Listing fee')
			it('Royalty')
			it('Changing min price')
			it('Changing fee')
			it('Changing payment currency')
		})
		
		describe('Withdraw', () => {
			it('AccessControl', async () => {
				const { Market } = await listBatch1155({})
				const [, user] = await ethers.getSigners()

				await expect(Market.connect(user).withdraw()).to.rejectedWith(
					accessError(await Market.DEFAULT_ADMIN_ROLE(), user.address)
				)
			})
			it('Transfer', async () => {
				const { USDT, wallets, Market } = await contracts()
			
				const { Collection1155 } = await listBatch1155({ Market })
				const [id] = await Market.items()
	
				const item = await Market.item(id)
				const [owner, buyer] = wallets
	
				const amount = await Collection1155.balanceOf(Market.address, item.id)
				const balance = await USDT.balanceOf(owner.address)
	
				await USDT.connect(buyer).approve(Market.address, item.price * amount)
				await Market.connect(buyer).buy(id, amount)

				expect(await USDT.balanceOf(Market.address)).to.equal(item.price * amount)

				await Market.connect(owner).withdraw()

				expect(await USDT.balanceOf(Market.address)).to.equal(0)
				expect(await USDT.balanceOf(owner.address)).to.equal(+balance + item.price * amount)

			})
			it('Changing withdraw address')
		})
	})

	describe('Reading data', () => {
		it('Single item info')

		it('List of all items', async () => {
			const { Market } = await contracts()
			await Promise.all([
				list1155({ Market }), listBatch1155({ Market }), list721({ Market })
			])

			expect((await Market.items()).length).to.equals(7)
		})

		it('List of available items', async () => {
			const { Market, Collection1155, items, USDT } = await listBatch1155({})
			const all = await Market.items()
			const [,buyer] = await ethers.getSigners()
			const amount = await Collection1155.balanceOf(Market.address, items[0].id)

			expect(await Market.itemsAvailable()).to.deep.equals(all)

			await USDT.connect(buyer).approve(Market.address, items[0].price)
			await Market.connect(buyer).buy(all[0], amount)

			expect(await Market.itemsAvailable()).to.deep.equals(all.slice(1))
		})

		it.only('List of owned items', async () => {
			const { Market, items, USDT } = await listBatch1155({})
			const all = await Market.items()
			const [,buyer] = await ethers.getSigners()

			expect(await Market.itemsAvailable()).to.deep.equals(all)

			await USDT.connect(buyer).approve(Market.address, items[0].price)
			await Market.connect(buyer).buy(all[0], 1)
			await USDT.connect(buyer).approve(Market.address, items[1].price)
			await Market.connect(buyer).buy(all[1], 1)

			expect(await Market.itemsOfOwner(buyer.address)).to.deep.equals([all[0], all[1]])
		})

		it('List of sold items')

		it('List of collections', async () => {
			const { Collection721: collection1, Market } = await list721({})
			const { Collection721: collection2 } = await list721({ Market })

			expect(
				await Market.collections()
			).to.deep.equals([collection1.address, collection2.address])
		})

		it('List of authors', async () => {
			const authors = await ethers.getSigners()
			const { Market } = await list721({})

			for (const author of authors) await list721({ Market, author })

			expect(
				await Market.authors()
			).to.deep.equals(authors.map(author => author.address))
		})

		it('List of items by collection', async () => {
			const { Market } = await contracts()
			const [{ Collection1155: { address } }] = await Promise.all([
				listBatch1155({ Market }), list1155({ Market }), list721({ Market })
			])

			expect((await Market.itemsByCollection(address)).length).to.equals(5)
		})

		it('List of items by author', async () => {
			const [, author] = await ethers.getSigners()
			const { Market } = await contracts()

			await list721({ Market })
			await listBatch1155({ Market, author })
			
			expect((await Market.itemsByAuthor(author.address)).length).to.equals(5)
		})
	})
})	  

// proxy
// item storage

// Auction
// - 
// Bid
// Buy now
// bids
// top bid
// endDate
// startDate


// Burn all tokens on chain migration	