const GardensTemplate = artifacts.require("GardensTemplate")
const Token = artifacts.require("Token")

const DAO_ID = "gardens" + Math.random() // Note this must be unique for each deployment, change it for subsequent deployments
const INITIAL_SUPERVISOR = "0xb4124cEB3451635DAcedd11767f004d8a28c6eE7"
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

const DAYS = 24 * 3600
const PPM = 1e6

// Create dao transaction one config
const ORG_TOKEN_NAME = "OrgToken"
const ORG_TOKEN_SYMBOL = "OGT"
const SUPPORT_REQUIRED = 50e16 // 50%
const MIN_ACCEPTANCE_QUORUM = 20e16 // 20%
const VOTE_DURATION_BLOCKS = 15
const VOTE_BUFFER_BLOCKS = 10
const VOTE_EXECUTION_DELAY_BLOCKS = 5
const VOTING_SETTINGS = [SUPPORT_REQUIRED, MIN_ACCEPTANCE_QUORUM, VOTE_DURATION_BLOCKS, VOTE_BUFFER_BLOCKS, VOTE_EXECUTION_DELAY_BLOCKS]
const USE_AGENT_AS_VAULT = false

// Create dao transaction two config
const TOLLGATE_FEE = 1e18
const USE_CONVICTION_AS_FINANCE = true
const FINANCE_PERIOD = 0 // Irrelevant if using conviction as finance

// Create dao transaction three config
const PRESALE_GOAL = 1000e18
const PRESALE_PERIOD = 14 * DAYS
const PRESALE_EXCHANGE_RATE = 1 * PPM
const VESTING_CLIFF_PERIOD = 90 * DAYS
const VESTING_COMPLETE_PERIOD = 360 * DAYS
const PRESALE_PERCENT_SUPPLY_OFFERED = 1 * PPM // 100%
const PRESALE_PERCENT_FUNDING_FOR_BENEFICIARY = 0.5 * PPM // 50%
const OPEN_DATE = 0
const BATCH_BLOCKS = 1
const BUY_FEE_PCT = 25 * Math.pow(10, 16)
const SELL_FEE_PCT = 25 * Math.pow(10, 16)
const MAXIMUM_TAP_RATE_INCREASE_PCT = 5 * Math.pow(10, 17)
const MAXIMUM_TAP_FLOOR_DECREASE_PCT = 5 * Math.pow(10, 17)

// Create dao transaction four config
const VIRTUAL_SUPPLY = 2
const VIRTUAL_BALANCE = 1
const RESERVE_RATIO = 0.1 * PPM
const SLIPPAGE = 2 * Math.pow(10, 17)
const TAP_RATE =  1 * PPM
const TAP_FLOOR = Math.pow(10, 21)

module.exports = async (callback) => {
  try {
    const gardensTemplate = await GardensTemplate.at(gardensTemplateAddress())

    const HNY = await Token.new(INITIAL_SUPERVISOR, "Honey", "HNY")
    console.log(`Created HNY Token: ${HNY.address}`)

    const createDaoTxOneReceipt = await gardensTemplate.createDaoTxOne(
      ORG_TOKEN_NAME,
      ORG_TOKEN_SYMBOL,
      [INITIAL_SUPERVISOR],
      VOTING_SETTINGS,
      USE_AGENT_AS_VAULT
    );
    console.log(`Tx One Complete. DAO address: ${createDaoTxOneReceipt.logs.find(x => x.event === "DeployDao").args.dao} Gas used: ${createDaoTxOneReceipt.receipt.gasUsed} `)

    const createDaoTxTwoReceipt = await gardensTemplate.createDaoTxTwo(
      HNY.address,
      TOLLGATE_FEE,
      [HNY.address],
      USE_CONVICTION_AS_FINANCE,
      HNY.address,
      FINANCE_PERIOD
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
      MAXIMUM_TAP_FLOOR_DECREASE_PCT,
      [HNY.address]
    )
    console.log(`Tx Three Complete. Gas used: ${createDaoTxThreeReceipt.receipt.gasUsed}`)

    const createDaoTxFourReceipt = await gardensTemplate.createDaoTxFour(
      daoId(),
      VIRTUAL_SUPPLY,
      VIRTUAL_BALANCE,
      RESERVE_RATIO,
      SLIPPAGE,
      TAP_RATE,
      TAP_FLOOR
    )
    console.log(`Tx Four Complete. Gas used: ${createDaoTxFourReceipt.receipt.gasUsed}`)


  } catch (error) {
    console.log(error)
  }
  callback()
}
