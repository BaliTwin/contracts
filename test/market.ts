import { expect } from 'chai'
import { ethers } from 'hardhat'

import { 
	contracts, accessError, randomInt,
	ipfsCID, randomPrice, invoice, nullData,
	list1155, listBatch1155
} from './fixtures'

const { defaultAbiCoder : AbiCoder } = ethers.utils

describe('Market', () => {
	describe('Listing', () => {
		it('Min price validation', async () => {
			const [, author] = await ethers.getSigners()
			const { Market, Collection1155 } = await contracts()

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
			await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection1155.address)

			const minPrice = await Market.minPrice()

			await expect(Collection1155.connect(author).mint(
				Market.address, ipfsCID(), 1, invoice(minPrice / 2 >> 0)
			)).to.revertedWith('Price must be greater than minimal price')

			await Collection1155.connect(author).mint(
				Market.address, ipfsCID(), 1, invoice(minPrice)
			)

			await expect(
				Market.connect(author).setMinPrice(randomPrice())
			).to.revertedWith(accessError(
				await Market.DEFAULT_ADMIN_ROLE(), author.address
			))
			
			const newMinPrice = randomPrice()
			await Market.setMinPrice(newMinPrice)

			expect(await Market.minPrice()).equals(newMinPrice)

			await expect(Collection1155.connect(author).mint(
				Market.address, ipfsCID(), 1, invoice(newMinPrice / 2 >> 0)
			)).to.revertedWith('Price must be greater than minimal price')
			
			await Collection1155.connect(author).mint(
				Market.address, ipfsCID(), 1, invoice(newMinPrice)
			)
		})
		
		it('Only for verified collections', async () => {
			const [author] = await ethers.getSigners()
			const { Market, Collection1155 } = await contracts()

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)	
			await expect(
				Collection1155.mint(Market.address, ipfsCID(), 1, invoice())
			).to.revertedWith(
				accessError(await Market.VERIFIED_COLLECTION(), Collection1155.address)
			)
		})

		it('Listing by single mint', async () => {
			const { 
				Market, Collection1155,
				id, price, author 
			} = await list1155({})
 			const listed = await Market.item((await Market.items())[0])

			expect(listed.id).to.equal(id)
			expect(listed.collection).to.equal(Collection1155.address)
			expect(listed.price).to.equal(price)
			expect(listed.author).to.equal(author.address)
			expect(listed.seller).to.equal(author.address)

			await Collection1155
				.connect(author)
				.mint(Market.address, id, randomInt(), invoice())
				.then(tx => tx.wait())

			// No dublicates on refill
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

			const listed = await Market.item((await Market.items())[0])

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
				const item = await Market.item(listed[i])

				expect(item.id).to.equals(items[i].id)
				expect(item.collection).to.equals(Collection1155.address)
				expect(item.price).to.equals(items[i].price)
				expect(item.author).to.equals(author.address)
				expect(item.seller).to.equals(author.address)
			}
		})

		it('Listing by transfer batch of 1155', async () => {
			const [, author, seller] = await ethers.getSigners()
			const { Market, Collection1155 } = await contracts()

			await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
			await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection1155.address)

			const ids = await Promise.all(Array(5).fill(0).map(ipfsCID))
			const amounts = ids.map(() => randomInt() || 1)
			const prices = ids.map(randomPrice)
			const datas = AbiCoder.encode(
				['bytes[]'], [prices.map(price => invoice(price))]
			)

			await Collection1155.connect(author).mintBatch(seller.address, ids, amounts, datas)
			await Collection1155
				.connect(seller)
				['safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)']
				(seller.address, Market.address, ids, amounts, datas)

			const listed = await Market.items()
			expect(listed.length).to.equal(5)

			for (let i = 0; i < listed.length; i++) {
				const item = await Market.item(listed[i])
				
				expect(item.id).to.equals(ids[i])
				expect(item.collection).to.equals(Collection1155.address)
				expect(item.price).to.equals(prices[i])
				expect(item.author).to.equals(author.address)
				expect(item.seller).to.equals(seller.address)
			}
		})

		it('Unlist', async () => {
			const { Market, author, Collection1155, id } = await list1155({})
			const [itemId] = await Market.items()

			expect(await Collection1155.balanceOf(author.address, id)).to.equal(0)
			expect(await Collection1155.balanceOf(Market.address, id)).to.equal(1)
			
			await Market.connect(author).unlist(itemId)

			expect((await Market.items()).find(id => id === itemId)).to.undefined

			expect(await Collection1155.balanceOf(author.address, id)).to.equal(1)
			expect(await Collection1155.balanceOf(Market.address, id)).to.equal(0)
		})
	})

	describe('Purchase', () => {
		it('buy()', async () => {
			const { USDT, Market } = await contracts()
			const [, buyer] = await ethers.getSigners()

			const { Collection1155, seller } = await listBatch1155({ Market })

			const [id] = await Market.items()
			const item = await Market.item(id)
			const amount = await Collection1155.balanceOf(Market.address, item.id)

			const buyerBalance = await USDT.balanceOf(buyer.address)
			const sellerBalance = await USDT.balanceOf(seller.address)
			const marketBalance = await USDT.balanceOf(Market.address)

			await Market.setListingFee(randomInt())
			const fee = item.price * amount / 100 * await Market.listingFee()
			
			expect(await Collection1155.balanceOf(buyer.address, item.id)).to.equal(0)

			await USDT.connect(buyer).approve(Market.address, item.price * amount)
			await Market.connect(buyer).buy(id, amount)

			const profit = item.price * amount - fee

			expect(await USDT.balanceOf(Market.address)).to.equal(marketBalance + fee)
			expect(await USDT.balanceOf(buyer.address)).to.equal(buyerBalance - item.price * amount)
			expect(await USDT.balanceOf(seller.address)).to.equal(+sellerBalance + profit)

			expect(await Collection1155.balanceOf(Market.address, item.id))
				.to.equal(0)
			expect(await Collection1155.balanceOf(buyer.address, item.id))
				.to.equal(amount)
		})
	})

	describe('Reading data', () => {
		it('item(): Single item info', async () => {
			const { Market, Collection1155, id, author, seller, price } = await list1155({ })
			const item = await Market.item(0)
			
			expect(item.id).equals(id)
			expect(item.collection).equals(Collection1155.address)
			expect(item.author).equals(author.address)
			expect(item.price).equals(price)
			expect(item.seller).equals(seller.address)
		})

		it('items(): List of all items', async () => {
			const { Market } = await contracts()
			await Promise.all([
				list1155({ Market }), listBatch1155({ Market })
			])

			expect((await Market.items())).deep.equals([...Array(6)].map((_,i) => i))
		})

		it('itemsAvailable(): List of available items', async () => {
			const { Market, Collection1155, items, USDT } = await listBatch1155({})
			const all = await Market.items()
			const [,buyer] = await ethers.getSigners()
			const amount = await Collection1155.balanceOf(Market.address, items[0].id)

			expect(await Market.itemsAvailable()).to.deep.equals(all)

			await USDT.connect(buyer).approve(Market.address, items[0].price * amount)
			await Market.connect(buyer).buy(all[0], amount)

			expect(await Market.itemsAvailable()).to.deep.equals(all.slice(1))
		})

		it('itemsOfOwner(): List of owned items', async () => {
			const { Collection1155, Market, items, USDT } = await listBatch1155({})
			const all = await Market.items()
			const [,buyer] = await ethers.getSigners()

			await USDT.connect(buyer).approve(Market.address, items[0].price)
			await Market.connect(buyer).buy(all[0], 1)
			await USDT.connect(buyer).approve(Market.address, items[1].price)
			await Market.connect(buyer).buy(all[1], 1)

			expect(await Market.itemsOfOwner(buyer.address)).deep.equals([all[0], all[1]])
		})

		it('collections(): List of collections', async () => {
			const { Collection1155: collection1, Market } = await list1155({})
			const { Collection1155: collection2 } = await list1155({ Market })

			expect(
				await Market.collections()
			).to.deep.equals([collection1.address, collection2.address])
		})

		it('authors(): List of authors', async () => {
			const authors = await ethers.getSigners()
			const { Market } = await list1155({})

			for (const author of authors) await list1155({ Market, author })

			expect(
				await Market.authors()
			).to.deep.equals(authors.map(author => author.address))
		})

		it('itemsByCollection(): List of items by collection', async () => {
			const { Market } = await contracts()
			const [{ Collection1155: { address } }] = await Promise.all([
				listBatch1155({ Market }), list1155({ Market })
			])

			expect((await Market.itemsByCollection(address)).length).to.equals(5)
		})

		it('itemsByAuthor(): List of items by author', async () => {
			const [, author] = await ethers.getSigners()
			const { Market } = await contracts()

			await list1155({ Market })
			await listBatch1155({ Market, author })
			
			expect((await Market.itemsByAuthor(author.address)).length).to.equals(5)
		})
	})

	describe('Admin functions', () => {
		it('setListingFee(): Update listing fee', async () => {
			const [, user] = await ethers.getSigners()
			const { Market } = await contracts()

			const newListingFee = randomInt()
			await expect(Market.connect(user).setListingFee(newListingFee)).rejectedWith(
				accessError(await Market.DEFAULT_ADMIN_ROLE(), user.address)
			)
			
			await Market.setListingFee(newListingFee)
			expect(await Market.listingFee()).equals(newListingFee)
		})

		it('setPaymentCurrency(): Update payment currency', async () => {
			const [, user] = await ethers.getSigners()
			const { Market, USDT } = await contracts()

			expect(await Market.paymentCurrency()).equals(USDT.address)

			const newPaymentCurrency = (await contracts()).USDT.address
			await expect(Market.connect(user).setPaymentCurrency(newPaymentCurrency)).rejectedWith(
				accessError(await Market.DEFAULT_ADMIN_ROLE(), user.address)
			)
			
			await Market.setPaymentCurrency(newPaymentCurrency)
			expect(await Market.paymentCurrency()).equals(newPaymentCurrency)
		})

		describe('withdraw()', () => {
			it('AccessControl', async () => {
				const { Market } = await listBatch1155({})
				const [, user] = await ethers.getSigners()

				await expect(Market.connect(user).withdraw()).to.rejectedWith(
					accessError(await Market.DEFAULT_ADMIN_ROLE(), user.address)
				)
			})

			it('Transfer', async () => {
				const [owner, author, buyer] = await ethers.getSigners()
				const { USDT, Market } = await contracts()
			
				const { Collection1155 } = await listBatch1155({ Market, author })
				const [id] = await Market.items()
				const item = await Market.item(id)
	
				const amount = await Collection1155.balanceOf(Market.address, item.id)
				const ownerBalance = await USDT.balanceOf(owner.address)
	
				await USDT.connect(buyer).approve(Market.address, item.price * amount)
				await Market.connect(owner).setListingFee(randomInt())
				await Market.connect(buyer).buy(id, amount)

				const marketBalance = await USDT.balanceOf(Market.address)
				await Market.connect(owner).withdraw()

				expect(await USDT.balanceOf(Market.address)).to.equal(0)
				expect(await USDT.balanceOf(owner.address)).to.equal(+ownerBalance + +marketBalance)

			})
		})
		it('destroy()', async () => {
			const [owner, user, author] = await ethers.getSigners()
			
			const { USDT, Market } = await contracts()
			const { id, Collection1155 } = await list1155({ author, USDT, Market })
			
			await USDT.connect(user).transfer(Market.address, randomPrice())
			
			const amount = await Collection1155.balanceOf(Market.address, id)
			const ownerBalance = await USDT.balanceOf(owner.address)
			const marketBalance = await USDT.balanceOf(Market.address)
			
			await expect(Market.connect(user).destroy()).rejectedWith(
				accessError(await Market.DEFAULT_ADMIN_ROLE(), user.address)
			)

			await Market.destroy()
			
			expect(await USDT.balanceOf(owner.address)).equals(+ownerBalance + +marketBalance)
			expect(await Collection1155.balanceOf(author.address, id)).equals(amount)
			expect(await owner.provider.getCode(Market.address)).equals('0x')
		})
	})
})


// events