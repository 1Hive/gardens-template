# Gardens Template 

Aragon DAO Template to experiment with public community coordination.

## Local deployment

To deploy the DAO to a local `aragon devchain`:

1) Install dependencies:
```
$ npm install
```

2) In a separate console run Aragon Devchain:
```
$ npx aragon devchain
```

3) From the output of the above copy the ENS address from "ENS instance deployed at:" to `arapp_local.json` `environments.devnet.registry`

4) In a separate console run the Aragon Client:
```
$ npx aragon start
```

5) Deploy the template with:
```
$ npm run deploy:rpc
```

6) Deploy the Conviction Voting app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/1Hive/conviction-voting-app
- Run `npm install` in the root folder
- Execute `npm run build` in the root folder
- Execute `aragon apm publish major --files dist --skip-confirmation` in the root folder

7) Deploy the Dandelion Voting app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/1Hive/dandelion-voting-app
- Run `npm install` in the root folder
- Execute `npm run build` in the root folder
- Execute `npm run publish:major` in the root folder

8) Deploy the Redemptions app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/1Hive/redemptions-app
- Run `npm install` in the root folder
- Execute `npm run build` in the root folder
- Execute `npm run publish:major` in the root folder

9) Deploy the Tollgate app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/aragonone/tollgate
- Run `npm install` in the root folder
- Execute `npm run build` in the root folder
- Execute `aragon apm publish major --skip-confirmation` in the root folder

10) Deploy the Fundraising suite Presale app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/AragonBlack/fundraising
- Add these lines to the `apps/presale/package.json` dependencies section:
```
    "@ablack/fundraising-shared-interfaces": "^1.0.0",
    "@ablack/fundraising-shared-test-helpers": "^1.0.0"
```
- Run `npm install` in the `apps/presale` folder
- Execute `aragon apm publish major --skip-confirmation` in the `apps/presale` folder

11) Create a new Gardens Dao on the devchain (each time this is called the `DAO_ID` const or `daoid` argument must be changed to something unused):
```
$ npx truffle exec scripts/new-dao.js --network rpc --daoid <unique id>
```

12) Copy the output DAO address into this URL and open it in a web browser:
```
http://localhost:3000/#/<DAO address>
```
