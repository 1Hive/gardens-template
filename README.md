# Gardens Template 

Aragon DAO Template to experiment with public community coordination.

## Local deployment

To deploy a Gardens DAO to a local `aragon devchain`:

1) Install dependencies:
```
$ npm install
```

2) In a separate console run Aragon Devchain:
```
$ npx aragon devchain
```

3) From the output of the above copy the ENS address from "ENS instance deployed at:" to `arapp_local.json` `environments.devnet.registry`

4) In a separate console run start IPFS:
```
$ npx aragon ipfs start
```

5) In a separate console run the Aragon Client:
```
$ npx aragon start
```

6) Deploy the template with:
```
$ npm run deploy:rpc
```

7) Deploy the Conviction Voting app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/1Hive/conviction-voting-app/tree/hooks
- Run `npm install` in the root folder
- Run `npm run build` in the root folder
- Run `npx aragon apm publish major --files dist --skip-confirmation` in the root folder

8) Deploy the Dandelion Voting app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/1Hive/dandelion-voting-app/tree/use-hooked-token-manager
- Run `npm install` in the root folder
- Run `npm run build` in the root folder
- Run `npx aragon apm publish major --files dist --skip-confirmation` in the root folder

9) Deploy the Redemptions app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/1Hive/redemptions-app
- Run `npm install` in the root folder
- Run `npm run build` in the root folder
- Run `npx aragon apm publish major --files dist --skip-confirmation` in the root folder

10) Deploy the Tollgate app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/aragonone/tollgate
- Run `npm install` in the root folder
- Run `npm run build` in the root folder
- Run `npx aragon apm publish major --skip-confirmation` in the root folder

11) Deploy the Fundraising suite Presale app:
- Download https://github.com/1Hive/aragon-fundraising
- Run `npm install` in the `apps/presale` folder
- Run `npx aragon apm publish major --skip-confirmation` in the `apps/presale` folder

12) Update the Fundraising app's UI (using the repo downloaded in the previous step):
- Run `npm install` in the `apps/aragon-fundraising` folder
- Run `npm run build`
- Run `npx aragon apm publish major --files app/build --skip-confirmation` in the `apps/aragon-fundraising` folder

13) Deploy the Hooked Token Manager app to the devchain as it's not installed by default like the other main apps 
(Voting, Token Manager, Agent etc):
- Download https://github.com/1hive/token-manager-app/
- Run `npm install` in the root folder
- Run `npm run build` in the root folder
- Run `npx aragon apm publish major --files dist --skip-confirmation` in the root folder

14) Create a new Gardens Dao on the devchain:
```
$ npx truffle exec scripts/new-dao.js --network rpc
```

15) Copy the output DAO address into this URL and open it in a web browser:
```
http://localhost:3000/#/<DAO address>
```


## Rinkeby deployment using previously deployed template

To deploy a Gardens DAO to Rinkeby:

1) Install dependencies:
```
$ npm install
```

2) Compile contracts:
```
$ npx truffle compile
```

3) Configure your DAO in: `scripts/new-dao.js` 

4) Deploy a DAO to Rinkeby (requires a Rinkeby account accessible by the truffle script as documented here: 
https://hack.aragon.org/docs/cli-intro#set-a-private-key):
```
$ npx truffle exec scripts/new-dao.js --network rinkeby
```

5) Copy the output DAO address into this URL and open it in a web browser:
```
https://rinkeby.aragon.org/#/<DAO address>
```