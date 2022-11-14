// Copyright (c) 2022, Bytedance Ltd. and/or its affiliates.
// Author：Jeddak Team
// All rights reserved.

//This source code is licensed under the license found in the
//LICENSE file in the root directory of this source tree.

// SPDX-License-Identifier: BSD 3-Clause License

pragma experimental ABIEncoderV2;
pragma solidity >=0.8.4;

contract pdfStorageAndRetrieval {
    int constant OFFSET19700101 = 2440588;
    uint constant SECONDSPERDAY = 24 * 60 * 60;

    //date struct
    struct Datetime {
        uint Year;
        uint Month;
        uint Day;
    }

    //certificate struct
    struct Certificate {
        string certificationType;
        string courseName;
        string userName;
        string completionDate;
        string expirationDate;
        string uploadDate;
        string pdfFileSize;
    }

    //store everychunk for every file
    mapping(string => mapping(uint=>bytes)) certificateFile;
    // uint certificateBytesLength;
    //store metadata for every file
    mapping(string => Certificate) certificateMata;

    //use filter file
    mapping(string => string[]) unameFiles;
    mapping(string => string[]) courseFiles;
    mapping(string => string[]) typeFiles;
    mapping(bytes => string[]) typeCourseFile;

    /*
    * @name insertCertificateChunk
    * @description Function used to upload a chunk of a certificate PDF via a byte array.
    * @param {string[] calldata} _metaData = [ certificationType, courseName, userName, completionDate, expirationDate, chunkFileName, uploadDate, pdfFileSize ]
    * example _metaData: [ “DBMI”, “Biomedical Informatics Responsible Conduct of Research”, “Jane Doe”, “09/21/2021”, “09/21/2024”, “10000000047.pdf.chunk1”, “09/24/2021”, “150103” ]
    * @param {bytes calldata} _data
    */
    function insertCertificateChunk( string[] calldata _metaData, bytes calldata _data) external {

        //get chunk_filename
        string memory fileNameStr =_metaData[5];
        //transfer chunk_filename to bytes
        bytes memory stringAsBytesArray = bytes(fileNameStr);


        uint index;

        //find filename
        for(uint i = 0; i < stringAsBytesArray.length; ++i) {
            if (stringAsBytesArray[i] == "." && stringAsBytesArray[i+1] == "c") {
                index=i;
                break;
            }
        }
        //1.1 use index to get filename
        bytes memory fileNameBytes = new bytes(index);
        for(uint i = 0; i < index; ++i) {
           fileNameBytes[i] = stringAsBytesArray[i];
        }

        //1.2 use index to get chunkindex
        uint j=0;
        bytes memory indexBytes = new bytes(stringAsBytesArray.length-(index+6));
        for(uint i = index+6; i < stringAsBytesArray.length; ++i) {
            indexBytes[j]=stringAsBytesArray[i];
            ++j;
        }

        uint chunkIndex=stringToUint(string(indexBytes));

        string memory fileName=string(fileNameBytes);

        Certificate storage c = certificateMata[fileName];
        //2.1 if not stored, to store
        if(keccak256(abi.encodePacked(c.certificationType)) == keccak256(abi.encodePacked(""))){
            //3.1 store metadata
            c.certificationType=_metaData[0];
            c.courseName=_metaData[1];
            c.userName=_metaData[2];
            c.completionDate=_metaData[3];
            c.expirationDate=_metaData[4];
            c.uploadDate=_metaData[6];
            c.pdfFileSize=_metaData[7];

            unameFiles[c.userName].push(fileName);
            typeCourseFile[abi.encodePacked(c.certificationType,c.courseName)].push(fileName);
            courseFiles[c.courseName].push(fileName);
            typeFiles[c.certificationType].push(fileName);
        }

         mapping(uint=>bytes) storage certificateBytes=certificateFile[fileName];
         certificateBytes[chunkIndex]=_data;
    }

    function stringToUint(string memory s) internal pure  returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; ++i) { // c = b[i] was not needed
            if (uint(uint8(b[i])) >= 48 && uint(uint8(b[i])) <= 57) {
                result = result * 10 + (uint(uint8(b[i])) - 48); // bytes and int are not compatible with the operator -.
            }
        }

        return result; // this was missing
    }

    /*
    * @name returnCertificateMetadata
    * @description This querying function returns the byte array of a TSV string that contains metadata for applicable on-chain PDFs given the requirements.
    * @param {string[] calldata} requirements = [ certificationType, courseName, userName ]
    * The wildcard “*” is a valid input for a metadata parameter, which stands for all possible inputs for this function. For example, requirements = ["DBMI", "*", "Jane Doe"]
    * We may have cases with up to two of the requirements being "*".
    * @param {boolean} notExpired. If true, only return metadata for non-expired PDFs. Otherwise, return metadata of all applicable PDFs regardless of expiration status.
    *
    * @returns {bytes memory} applicable pdf metadata as TSV byte array.
    * return format: "{certificationType}\t{courseName}\t{userName}\t{completionDate}\t{expirationDate}\t{fileName}\t{uploadDate}\t{pdfFileSize}\n"
    * Return example when converted into a string:
    * "DBMI\tBiomedical Informatics Responsible Conduct of Research\tJane Doe\t09/21/2021\t 09/21/2024\t10000000047.pdf\t09/24/2021\t150103\nDBMI\tBiomedical Informatics Research\tJane Doe\t10/01/2020\t10/01/2023\t30000000013.pdf\t10/29/2020\t709207\n"
	* If no on-chain pdf matches the requirements, return the byte array equivalence of "No certificate matches that query.\n".
    * Notice the "\t" characters between the intra-pdf metadata, and the "\n" between the inter-pdf metadata (and after the failed search message).
    */

    function returnCertificateMetadata( string[] calldata _requirements, bool _notExpired) external view returns(bytes memory){

        //1. init result array
        string[] memory resultIntersect;
        uint resultIntersectCount=0;

       (resultIntersect,resultIntersectCount)=getIntersectCer(_requirements);
       //1.1 if not have ，return no certificate...
       if (resultIntersectCount==0){
           return "No certificates matched that query.\n";
       }
       //2. is not expired
       string memory resultStr;
       if(_notExpired==false){
            resultStr=query1StringConcatent(resultIntersect,resultIntersectCount);
       }
       else{
        string[] memory resultIntersectNotexpired;
        uint resultIntersectNotexpiredCount;
        (resultIntersectNotexpired,resultIntersectNotexpiredCount)= notExpiredCertificate(resultIntersect,resultIntersectCount);
        if (resultIntersectNotexpiredCount==0) {
            return "No certificates matched that query.\n";
        }
        resultStr=query1StringConcatent(resultIntersectNotexpired,resultIntersectNotexpiredCount);
        }
        return bytes(resultStr);
    }

    //concat query1 result
     function query1StringConcatent(string[] memory filename,uint resultCount) internal view returns(string memory) {
      string memory result="";
      for(uint i=0;i<resultCount;++i){
          Certificate memory certificate=certificateMata[filename[i]];
          //{certificationType}\t{courseName}\t{userName}\t{completionDate}\t{expirationDate}\t{fileName}\t{uploadDate}\t{pdfFileSize}\n
          string memory tmp1=string(abi.encodePacked(certificate.certificationType, "\t",certificate.courseName, "\t",certificate.userName, "\t"));
          string memory tmp2 =string(abi.encodePacked(certificate.completionDate,"\t",certificate.expirationDate, "\t",filename[i], "\t"));
          string memory tmp3=string(abi.encodePacked(certificate.uploadDate, "\t",certificate.pdfFileSize,"\n"));
          result=string(abi.encodePacked(result,tmp1,tmp2,tmp3));
      }
      return result;
    }



    //transfer date
    function stringToDate(string memory s) internal pure returns (Datetime memory) {
        bytes memory b = bytes(s);
        Datetime memory date;
        //Month
        date.Month = (uint(uint8(b[0])) - 48) * 10 + (uint(uint8(b[1])) - 48);
        date.Day = (uint(uint8(b[3])) - 48) * 10 + (uint(uint8(b[4])) - 48);
        date.Year = (uint(uint8(b[6])) - 48) * 1000 + (uint(uint8(b[7])) - 48) * 100 + (uint(uint8(b[8])) - 48) * 10 + (uint(uint8(b[9])) - 48);
        return date;
    }

    //judge if the certificate with Filename s expired or not;
    //notexpired:true; expired:false;
    function IsNotExpired(string memory s) internal view returns (bool result) {
        //test if the date is not expired;
        Datetime memory date = stringToDate(s);
        uint datestamp = _secondsFromDate(date.Year,date.Month,date.Day) + 16*60*60;
        if (block.timestamp > datestamp){
            result = false;//guoqile
        }
        else{
            result = true;
        }
    }

    //choose filenames(notexpired certificate) from certificate;
    function notExpiredCertificate(string[] memory certificate,uint len) internal view returns (string[] memory,uint) {
        string[] memory result=new string[](len);
        uint j = 0;
        for(uint i=0;i<len;++i){
            if (IsNotExpired(certificateMata[certificate[i]].expirationDate)) {
                result[j] = certificate[i];
                j++;
            }
        }
        return (result,j);
    }

    //unix time transfer
    function _secondsFromDate(uint year, uint month, uint day) internal pure returns (uint _timestamp) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
          - OFFSET19700101;

        _timestamp = uint(__days) * SECONDSPERDAY;
    }

    //compare two dates using Datetime
    function CompareDate(Datetime memory a, Datetime memory b) internal pure returns(bool) {
        //compare a and b; return if a>b
        if (a.Year != b.Year){
            return (a.Year > b.Year) ? true:false;
        }
        else if (a.Month != b.Month){
            return (a.Month > b.Month) ? true:false;
        }
        else if (a.Day != b.Day){
            return (a.Day > b.Day) ? true:false;
        }
        else{
            return true;
        }
    }
    //compare two dates with the form of string
    function CompareString(string memory a,string memory b)  internal pure returns(bool){
        Datetime memory datea = stringToDate(a);
        Datetime memory dateb = stringToDate(b);
        return CompareDate(datea,dateb);
    }

    //get the cert of latest completedate;
    function getLatestCompletedate (string[] memory certificate,uint certificateLen) internal view returns (string memory) {
        string memory result = certificate[0];
        string memory tmp = certificateMata[certificate[0]].completionDate;
        for (uint i=1;i<certificateLen;i++) {
            if (CompareString(certificateMata[certificate[i]].completionDate,tmp)==true) {
                tmp = certificateMata[certificate[i]].completionDate;
                result = certificate[i];
            }
        }
        return result;
    }

    //if filename is not *
    function isMatchedByFilename(string[] calldata _requirements)  internal view returns(bool){
        string memory filename=_requirements[5];
        if(keccak256(abi.encodePacked(_requirements[0])) != keccak256(abi.encodePacked("*"))){
            if(keccak256(abi.encodePacked(certificateMata[filename].certificationType)) != keccak256(abi.encodePacked(_requirements[0]))){
                return false;
            }
        }
        if(keccak256(abi.encodePacked(certificateMata[filename].courseName)) != keccak256(abi.encodePacked(_requirements[1]))){
                return false;
         }
         if(keccak256(abi.encodePacked(certificateMata[filename].userName)) != keccak256(abi.encodePacked(_requirements[2]))){
                return false;
         }
         if(keccak256(abi.encodePacked(_requirements[3])) != keccak256(abi.encodePacked("*"))){
            if(CompareString(certificateMata[filename].completionDate,_requirements[3])==false){
                return false;
            }
        }
        if(keccak256(abi.encodePacked(_requirements[4])) != keccak256(abi.encodePacked("*"))){
            if(CompareString(certificateMata[filename].expirationDate,_requirements[4])==false){
                return false;
             }
        }
        if(keccak256(abi.encodePacked(_requirements[6])) != keccak256(abi.encodePacked("*"))){
            if(CompareString(certificateMata[filename].uploadDate,_requirements[6])==false){
                return false;
            }
        }
        return true;

     }


    /*
    * @name getCertificatePDF
    * @description Returns the most recent on-chain PDF that fulfills the requirements.
    * @param {string[] calldata} requirements = [ certificationType, courseName, userName, completionDate, expirationDate, fileName, uploadDate ]
    * The wildcard “*” is a valid input for a metadata parameter, which stands for all possible inputs for this function.
    * Note that “*” is a valid input for any metadata parameter for this function, except for courseName and userName.
	* @param {boolean} _notExpired. If true, only return the latest non-expired PDF based on completion date. Otherwise, return the latest PDF based on completion date regardless of expiration status.
    *
	* @returns {bytes memory} full PDF data as a byte array (i.e., chunk_1_data || chunk_2_data || … || chunk_n_data); in this context, “||” means concatenation.

    * If no on-chain PDF matches the requirements, return the byte array equivalence of "No certificate matches that query.\n".
    */
    function getCertificatePDF( string[] calldata _requirements, bool _notExpired) external view returns(bytes memory) {

        string memory result="";
        if(keccak256(abi.encodePacked(_requirements[5])) != keccak256(abi.encodePacked("*"))){
            bool resultFlag=isMatchedByFilename(_requirements);
            if(resultFlag==false){
                return "No certificates matched that query.\n";
            }
            else{
                result=_requirements[5];
            }
        }else{

            string memory completionDate=_requirements[3];
            string memory expirationDate=_requirements[4];
            string memory uploadDate=_requirements[6];

            string[] memory result1;
            uint resultCount1=0;
            (result1,resultCount1)=getIntersectCer(_requirements);

            if (resultCount1==0){
               return "No certificates matched that query.\n";
            }

            string[] memory result2=new string[](resultCount1);
            uint resultCount2=0;
            for(uint i=0;i<resultCount1;i++){
                if(keccak256(abi.encodePacked(completionDate)) != keccak256(abi.encodePacked("*"))){
                    if(CompareString(certificateMata[result1[i]].completionDate,completionDate)==false){
                        continue;
                    }
                }
                if(keccak256(abi.encodePacked(expirationDate)) != keccak256(abi.encodePacked("*"))){
                    if(CompareString(certificateMata[result1[i]].expirationDate,expirationDate)==false){
                        continue;
                    }
                }
                if(keccak256(abi.encodePacked(uploadDate)) != keccak256(abi.encodePacked("*"))){
                    if(CompareString(certificateMata[result1[i]].uploadDate,uploadDate)==false){
                        continue;
                    }
                }
                result2[resultCount2++]=result1[i];
            }
            if (resultCount2==0) {
                return "No certificates matched that query.\n";
            }

            result = getLatestCompletedate(result2,resultCount2);

        }
        if (_notExpired==true && IsNotExpired(certificateMata[result].expirationDate)==false) {
            return "No certificates matched that query.\n";
        }

        mapping(uint=>bytes) storage cer=certificateFile[result];
        bytes memory r16=abi.encodePacked(cer[1],cer[2],cer[3],cer[4],cer[5],cer[6]);
        bytes memory r712=abi.encodePacked(cer[7],cer[8],cer[9],cer[10],cer[11],cer[12]);
        bytes memory r1318=abi.encodePacked(cer[13],cer[14],cer[15],cer[16],cer[17],cer[18]);
        bytes memory r1924=abi.encodePacked(cer[19],cer[20],cer[21],cer[22],cer[23],cer[24]);
        bytes memory r2530=abi.encodePacked(cer[25],cer[26],cer[27],cer[28],cer[29],cer[30]);
        bytes memory r3136=abi.encodePacked(cer[31],cer[32],cer[33],cer[34],cer[35],cer[36]);
        bytes memory r3742=abi.encodePacked(cer[37],cer[38],cer[39],cer[40],cer[41],cer[42]);
        bytes memory r4348=abi.encodePacked(cer[43],cer[44],cer[45],cer[46],cer[47],cer[48]);
        bytes memory r4954=abi.encodePacked(cer[49],cer[50],cer[51],cer[52],cer[53],cer[54]);

        bytes memory tmp1=abi.encodePacked(r16,r712,r1318,r1924,r2530,r3136);
        bytes memory tmp2=gas78(result);
        return abi.encodePacked(tmp1,r3742,r4348,r4954,tmp2);
    }
    function gas78(string memory filename) internal view returns(bytes memory) {
        // uint gashasleft=gasleft();
        // emit Log(gashasleft);
        mapping(uint=>bytes) storage cer=certificateFile[filename];
        bytes memory r5560=abi.encodePacked(cer[55],cer[56],cer[57],cer[58],cer[59],cer[60]);
        bytes memory r6166=abi.encodePacked(cer[61],cer[62],cer[63],cer[64],cer[65],cer[66]);
        bytes memory r6772=abi.encodePacked(cer[67],cer[68],cer[69],cer[70],cer[71],cer[72]);
        bytes memory r7378=abi.encodePacked(cer[73],cer[74],cer[75],cer[76],cer[77],cer[78]);
        bytes memory r7980=abi.encodePacked(cer[79],cer[80]);
        bytes memory tmp2=abi.encodePacked(r5560,r6166,r6772,r7378,r7980);
        return tmp2;
        // gashasleft=gasleft();
        // emit Log(gashasleft);
    }

    //get matched files
    function getIntersectCer(string[] calldata _requirements) internal view returns (string[] memory,uint) {
        string memory ctype=_requirements[0];
        string memory course=_requirements[1];
        string memory uname=_requirements[2];


        string[] memory result;
        uint256 j = 0;
        if(keccak256(abi.encodePacked(uname)) != keccak256(abi.encodePacked("*"))){
            string[] storage unameFilesA=unameFiles[uname];
            uint unameFilesALen=unameFilesA.length;
            result=new string[](unameFilesALen);
            if(keccak256(abi.encodePacked(course)) != keccak256(abi.encodePacked("*"))){
                if(keccak256(abi.encodePacked(ctype)) != keccak256(abi.encodePacked("*"))){
                    for(uint i=0;i<unameFilesALen;i++){
                        string memory filename=unameFilesA[i];
                        if(keccak256(abi.encodePacked(certificateMata[filename].certificationType))== keccak256(abi.encodePacked(ctype)) &&
                        keccak256(abi.encodePacked(certificateMata[filename].courseName))== keccak256(abi.encodePacked(course))){
                            result[j++]=filename;
                        }
                    }

                }else{
                    for(uint i=0;i<unameFilesALen;i++){
                        string memory filename=unameFilesA[i];
                        if(keccak256(abi.encodePacked(certificateMata[filename].courseName))== keccak256(abi.encodePacked(course))){
                            result[j++]=filename;
                        }
                    }
                }
            }else{
                if(keccak256(abi.encodePacked(ctype)) != keccak256(abi.encodePacked("*"))){
                   for(uint i=0;i<unameFilesALen;i++){
                        string memory filename=unameFilesA[i];
                        if(keccak256(abi.encodePacked(certificateMata[filename].certificationType))== keccak256(abi.encodePacked(ctype))){
                            result[j++]=filename;
                        }
                    }
                }else{
                    result=unameFilesA;
                    j=unameFilesALen;
                }
            }
        }else{
             if(keccak256(abi.encodePacked(course)) != keccak256(abi.encodePacked("*"))){
                 if(keccak256(abi.encodePacked(ctype)) != keccak256(abi.encodePacked("*"))){
                     result=typeCourseFile[abi.encodePacked(ctype,course)];
                     j=result.length;
                 }else{
                    result=courseFiles[course];
                    j=result.length;
                 }
             }else{
                if(keccak256(abi.encodePacked(ctype)) != keccak256(abi.encodePacked("*"))){
                    result=typeFiles[ctype];
                    j=result.length;
                }
             }
        }

        return (result,j);
    }

}