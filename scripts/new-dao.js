const GardensTemplate = artifacts.require("GardensTemplate")
const Token = artifacts.require("Token")

const DAO_ID = "gardens" + Math.random() // Note this must be unique for each deployment, change it for subsequent deployments
const TOKEN_OWNER = "0xb4124cEB3451635DAcedd11767f004d8a28c6eE7"
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
  } else {
    const Arapp = require("../arapp_local")
    return Arapp.environments.devnet.address
  }
}

const DAYS = 24 * 60 * 60
const ONE_HUNDRED_PERCENT = 1e18
const ONE_TOKEN = 1e18
const FUNDRAISING_ONE_HUNDRED_PERCENT = 1e6
const FUNDRAISING_ONE_TOKEN = 1e6

const COLLATERAL_TOKEN_NAME = "Wasethes"
const COLLATERAL_TOKEN_SYMBOL = "WAH"

// Create dao transaction one config
const ORG_TOKEN_NAME = "OrgToken"
const ORG_TOKEN_SYMBOL = "OGT"
const SUPPORT_REQUIRED = 0.5 * ONE_HUNDRED_PERCENT
const MIN_ACCEPTANCE_QUORUM = 0.2 * ONE_HUNDRED_PERCENT
const VOTE_DURATION_BLOCKS = 15
const VOTE_BUFFER_BLOCKS = 10
const VOTE_EXECUTION_DELAY_BLOCKS = 5
const VOTING_SETTINGS = [SUPPORT_REQUIRED, MIN_ACCEPTANCE_QUORUM, VOTE_DURATION_BLOCKS, VOTE_BUFFER_BLOCKS, VOTE_EXECUTION_DELAY_BLOCKS]
const USE_AGENT_AS_VAULT = false

// Create dao transaction two config
const TOLLGATE_FEE = ONE_TOKEN
const USE_CONVICTION_AS_FINANCE = true
const FINANCE_PERIOD = 0 // Irrelevant if using conviction as finance

// Create dao transaction three config
const PRESALE_GOAL = 1000 * ONE_TOKEN
const PRESALE_PERIOD = 14 * DAYS
const PRESALE_EXCHANGE_RATE = FUNDRAISING_ONE_TOKEN
const VESTING_CLIFF_PERIOD = 90 * DAYS
const VESTING_COMPLETE_PERIOD = 360 * DAYS
const PRESALE_PERCENT_SUPPLY_OFFERED = FUNDRAISING_ONE_HUNDRED_PERCENT
const PRESALE_PERCENT_FUNDING_FOR_BENEFICIARY = 0.5 * FUNDRAISING_ONE_HUNDRED_PERCENT
const OPEN_DATE = 0
const BATCH_BLOCKS = 1
const BUY_FEE_PCT = 0.2 * ONE_HUNDRED_PERCENT
const SELL_FEE_PCT = 0.2 * ONE_HUNDRED_PERCENT
const MAXIMUM_TAP_RATE_INCREASE_PCT = 0.5 * ONE_HUNDRED_PERCENT
const MAXIMUM_TAP_FLOOR_DECREASE_PCT = 0.5 * ONE_HUNDRED_PERCENT

// Create dao transaction four config
const VIRTUAL_SUPPLY = 2
const VIRTUAL_BALANCE = 1
const RESERVE_RATIO = 0.1 * FUNDRAISING_ONE_HUNDRED_PERCENT
const SLIPPAGE = 0.2 * ONE_HUNDRED_PERCENT
const TAP_RATE_PER_BLOCK = 0
const TAP_FLOOR = 0

module.exports = async (callback) => {
  try {
    const gardensTemplate = await GardensTemplate.at(gardensTemplateAddress())

    const collateralToken = await Token.new(TOKEN_OWNER, COLLATERAL_TOKEN_NAME, COLLATERAL_TOKEN_SYMBOL)
    console.log(`Created ${COLLATERAL_TOKEN_SYMBOL} Token: ${collateralToken.address}`)

    const createDaoTxOneReceipt = await gardensTemplate.createDaoTxOne(
      ORG_TOKEN_NAME,
      ORG_TOKEN_SYMBOL,
      VOTING_SETTINGS,
      USE_AGENT_AS_VAULT
    );
    console.log(`Tx One Complete. DAO address: ${createDaoTxOneReceipt.logs.find(x => x.event === "DeployDao").args.dao} Gas used: ${createDaoTxOneReceipt.receipt.gasUsed} `)

    const createDaoTxTwoReceipt = await gardensTemplate.createDaoTxTwo(
      collateralToken.address,
      TOLLGATE_FEE,
      [collateralToken.address],
      USE_CONVICTION_AS_FINANCE,
      FINANCE_PERIOD,
      collateralToken.address
    )
    console.log(`Tx Two Complete. Gas used: ${createDaoTxTwoReceipt.receipt.gasUsed}`)

    const createDaoTxThreeReceipt = await gardensTemplate.createDaoTxThree(
      PRESALE_GOAL,
      PRESALE_PERIOD,
      PRESALE_EXCHANGE_RATE,
      VESTING_CLIFF_PERIOD,
      VESTING_COMPLETE_PERIOD,
      PRESALE_PERCENT_SUPPLY_OFFERED,
      PRESALE_PERCENT_FUNDING_FOR_BENEFICIARY,
      OPEN_DATE,
      BATCH_BLOCKS,
      BUY_FEE_PCT,
      SELL_FEE_PCT,
      MAXIMUM_TAP_RATE_INCREASE_PCT,
      MAXIMUM_TAP_FLOOR_DECREASE_PCT
    )
    console.log(`Tx Three Complete. Gas used: ${createDaoTxThreeReceipt.receipt.gasUsed}`)

    const createDaoTxFourReceipt = await gardensTemplate.createDaoTxFour(
      daoId(),
      VIRTUAL_SUPPLY,
      VIRTUAL_BALANCE,
      RESERVE_RATIO,
      SLIPPAGE,
      TAP_RATE_PER_BLOCK,
      TAP_FLOOR
    )
    console.log(`Tx Four Complete. Gas used: ${createDaoTxFourReceipt.receipt.gasUsed}`)


  } catch (error) {
    console.log(error)
  }
  callback()
}
