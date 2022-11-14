# idash2022-track1-solution
Solution for [IDASH PRIVACY & SECURITY WORKSHOP 2022 - secure genome analysis competition](http://www.humangenomeprivacy.org/2022/competition-tasks.html) task 1 
# Introduction
Most of the existing biomedical and genomic compliance training certificates are stored in a centralized database, and there is a risk of a single-point-of-failure. Due to the characteristics of decentralized and distributed storage, blockchain can be used to solve this problem. Therefore, the purpose of this task is to benchmark the use of blockchain for storing and retrieving certificates.
# Prerequisites
Go-Ethereum 1.10.7, Solidity 0.8.12 (with ABI Encoder v2 enabled), and Ubuntu 18.04.5
# Contract compile
We compile our contract under Solidity 0.8.12, using the following command:

```
solc --optimize --bin --abi  --overwrite  --evm-version byzantium  -o. pdfStorageAndRetrieval.sol
```

Then, we will get pdfStorageAndRetrieval.bin and pdfStorageAndRetrieval.abi. You can deploy from the Go-Ethereum command line or in a plugin. 
## Security
If you discover a potential security issue in this project, or think you may
have discovered a security issue, we ask that you notify Bytedance Security via our [security center](https://security.bytedance.com/src) or [vulnerability reporting email](sec@bytedance.com).

Please do **not** create a public GitHub issue.
## License
This project is licensed under the BSD 3-Clause License.
# Contact Us
Welcome to review our algorithm or point out any problem if you want. Or if you have better ideas or want to discuss more with us, you can contact fengqingling@bytedance.com
