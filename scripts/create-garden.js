
const GardensTemplate = artifacts.require("GardensTemplate")
const Token = artifacts.require("Token")

const DAO_ID = "gardens" + Math.random() // Note this must be unique for each deployment, change it for subsequent deployments
const NETWORK_ARG = "--network"
const DAO_ID_ARG = "--daoid"

const argValue = (arg, defaultValue) => process.argv.includes(arg) ? process.argv[process.argv.indexOf(arg) + 1] : defaultValue

const network = () => argValue(NETWORK_ARG, "local")
const daoId = () => argValue(DAO_ID_ARG, DAO_ID)



const gardensTemplateAddress = () => {
  if (network() === "rinkeby") {
    const Arapp = require("../arapp")
    return Arapp.environments.rinkeby.address
  } else if (network() === "mainnet") {
    const Arapp = require("../arapp")
    return Arapp.environments.mainnet.address
  } else if (network() === "xdai") {
    const Arapp = require("../arapp")
    return Arapp.environments.xdai.address
  } else {
    const Arapp = require("../arapp_local")
    return Arapp.environments.devnet.address
  }
}

// Helpers, no need to change
const DAYS = 24 * 60 * 60
const ONE_HUNDRED_PERCENT = 1e18
const ONE_TOKEN = 1e18
const FUNDRAISING_ONE_HUNDRED_PERCENT = 1e6
const FUNDRAISING_ONE_TOKEN = 1e6

// CONFIGURATION

// Collateral Token is used to pay contributors and held in the bonding curve reserve
const COLLATERAL_TOKEN_ADDRESS = "0x1ea885084dd4747be71da907bd71fc9484af618d" // Rinkeby Test Honey can mint for yourself here https://rinkeby.aragon.org/#/honey/0x1a30a4c3a6679855e86fb9585b010929cfc8134a/
// Org Token represents membership in the community and influence in proposals
const ORG_TOKEN_NAME = "Flowers"
const ORG_TOKEN_SYMBOL = "FLW"

// Dandelion Voting Settings, Used for administrative or binary choice decisions with ragequit-like functionality
const SUPPORT_REQUIRED = 0.5 * ONE_HUNDRED_PERCENT
const MIN_ACCEPTANCE_QUORUM = 0.01 * ONE_HUNDRED_PERCENT
const VOTE_DURATION_BLOCKS = 180
const VOTE_BUFFER_BLOCKS = 60
const VOTE_EXECUTION_DELAY_BLOCKS = 60
const VOTING_SETTINGS = [SUPPORT_REQUIRED, MIN_ACCEPTANCE_QUORUM, VOTE_DURATION_BLOCKS, VOTE_BUFFER_BLOCKS, VOTE_EXECUTION_DELAY_BLOCKS]
// Set the fee paid to the org to create an administrative vote
const TOLLGATE_FEE = 1 * ONE_TOKEN


// If you want to use the Agent instead of the vault allowing the community to interact with external contracts
const USE_AGENT_AS_VAULT = false

// If you don't want to use conviction voting you can set this to false, not really recommened though.
const USE_CONVICTION_AS_FINANCE = true
const FINANCE_PERIOD = 0 // Irrelevant if using conviction as finance

// Marketplace Bonding Curve Parameterization

// Pre-sale or Hatch settings
const PRESALE_GOAL = 100 * ONE_TOKEN // How many tokens required to initialize the bonding curve
const PRESALE_PERIOD = 1 * DAYS // How long should the presale period last for
const PRESALE_EXCHANGE_RATE = FUNDRAISING_ONE_TOKEN // How many organization tokens per collateral token should be minted
const VESTING_CLIFF_PERIOD = 90 * DAYS // When is the cliff for vesting restrictions
const VESTING_COMPLETE_PERIOD = 360 * DAYS // When will pre-sale contributors be fully vested
const OPEN_DATE = 0 // when should the pre-sale be open, setting 0 will allow anyone to open the pre-sale anytime after deployment
const PRESALE_PERCENT_FUNDING_FOR_BENEFICIARY = 0.50 * FUNDRAISING_ONE_HUNDRED_PERCENT // What percentage of pre-sale contributions should go to the common pool (versus the reserve)

// Entry and Exit fee settings
const BUY_FEE_PCT = 0.2 * ONE_HUNDRED_PERCENT // percent of each "buy" that goes to the common pool
const SELL_FEE_PCT = 0.2 * ONE_HUNDRED_PERCENT // percent of each "sell" that goes to the common pool

// Bonding Curve reserve settings
const RESERVE_RATIO = 0.25 * FUNDRAISING_ONE_HUNDRED_PERCENT // Determines reserve ratio of the bonding curve, 100 percent is a 1:1 peg with collateral asset.

// Virtual Supply and Virtual balance can be used to adjust granularity of the curve, behavior will be most intuitive if you do not change these values.
const VIRTUAL_SUPPLY = 2
const VIRTUAL_BALANCE = 1



module.exports = async (callback) => {
  try {

    const gardensTemplate = await GardensTemplate.at(gardensTemplateAddress())

    //const collateralToken = await Token.new(TOKEN_OWNER, COLLATERAL_TOKEN_NAME, COLLATERAL_TOKEN_SYMBOL)
    //console.log(`Created ${COLLATERAL_TOKEN_SYMBOL} Token: ${collateralToken.address}`)
    const createDaoTxOneReceipt = await gardensTemplate.createDaoTxOne(
      ORG_TOKEN_NAME,
      ORG_TOKEN_SYMBOL,
      VOTING_SETTINGS,
      USE_AGENT_AS_VAULT
    );
    console.log(`Tx One Complete. DAO address: ${createDaoTxOneReceipt.logs.find(x => x.event === "DeployDao").args.dao} Gas used: ${createDaoTxOneReceipt.receipt.gasUsed} `)

    const createDaoTxTwoReceipt = await gardensTemplate.createDaoTxTwo(
      COLLATERAL_TOKEN_ADDRESS,
      TOLLGATE_FEE,
      [COLLATERAL_TOKEN_ADDRESS],
      USE_CONVICTION_AS_FINANCE,
      FINANCE_PERIOD,
      COLLATERAL_TOKEN_ADDRESS
    )
    console.log(`Tx Two Complete. Gas used: ${createDaoTxTwoReceipt.receipt.gasUsed}`)

    const createDaoTxThreeReceipt = await gardensTemplate.createDaoTxThree(
      PRESALE_GOAL,
      PRESALE_PERIOD,
      PRESALE_EXCHANGE_RATE,
      VESTING_CLIFF_PERIOD,
      VESTING_COMPLETE_PERIOD,
      FUNDRAISING_ONE_HUNDRED_PERCENT,
      PRESALE_PERCENT_FUNDING_FOR_BENEFICIARY,
      OPEN_DATE,
      BUY_FEE_PCT,
      SELL_FEE_PCT
    )
    console.log(`Tx Three Complete. Gas used: ${createDaoTxThreeReceipt.receipt.gasUsed}`)

    const createDaoTxFourReceipt = await gardensTemplate.createDaoTxFour(
      daoId(),
      VIRTUAL_SUPPLY,
      VIRTUAL_BALANCE,
      RESERVE_RATIO
    )
    console.log(`Tx Four Complete. Gas used: ${createDaoTxFourReceipt.receipt.gasUsed}`)


  } catch (error) {
    console.log(error)
  }
  callback()
}
