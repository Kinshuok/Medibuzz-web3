// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DoctorPatientPortal {
    address admin; // Contract admin

    enum Role { Patient, Doctor }

    struct User {
        string name;
        string loginId;
        string passwordHash;
        Role role;
        address[] authorizedDoctors;
        address[] authorizedPatients; // Directly store authorized patients
        mapping(address => string[]) medicalRecords;
    }
 
    mapping(address => User) public users; // Mapping of users
    address[] public allDoctors; // Array to store all doctor addresses
    address[] public allPatients; // Array to store all patient addresses

    event UserRegistered(address userAddress, string name, string loginId, Role role);
    event PermissionGranted(address doctorAddress, address patientAddress);
    event MedicalRecordUploaded(address doctorAddress, address patientAddress, string recordHash);
 

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function registerUser(string memory _name, string memory _loginId, string memory _passwordHash, Role _role) external {
        require(bytes(users[msg.sender].loginId).length == 0, "User already registered");
        User storage newUser = users[msg.sender];
        newUser.name = _name;
        newUser.loginId = _loginId;
        newUser.passwordHash = _passwordHash;
        newUser.role = _role;
        emit UserRegistered(msg.sender, _name, _loginId, _role);

        // If the registered user is a doctor, add their address to the list of all doctors
        if (_role == Role.Doctor) {
            allDoctors.push(msg.sender);
        } else {
            // If the registered user is a patient, add their address to the list of all patients
            allPatients.push(msg.sender);
        }
    }

    function loginUser(string memory _loginId, string memory _passwordHash) external view returns (Role) {
        address userAddress = msg.sender;
        require(keccak256(bytes(users[userAddress].loginId)) == keccak256(bytes(_loginId)), "Invalid loginId");
        require(keccak256(bytes(users[userAddress].passwordHash)) == keccak256(bytes(_passwordHash)), "Invalid password");
        return users[userAddress].role;
    }

    function getPatients() external view returns (address[] memory, string[] memory) {
        // Ensure that only doctors can access this function
        require(users[msg.sender].role == Role.Doctor, "Only doctors can access this function");

        // Get the list of authorized patients for the calling doctor
        address[] memory patientAddresses = users[msg.sender].authorizedPatients;
        string[] memory patientNames = new string[](patientAddresses.length);

        // Retrieve the names of authorized patients
        for (uint256 i = 0; i < patientAddresses.length; i++) {
            patientNames[i] = users[patientAddresses[i]].name;
        }

        return (patientAddresses, patientNames);
    }

    function grantPermission(address _doctorAddress) external returns (address) {
        // Ensure that only patients can grant permission
        require(users[msg.sender].role == Role.Patient, "Only patients can grant permission");

        // Check if permission has already been granted
        require(!isDoctorAuthorized(_doctorAddress), "Permission already granted");

        // Add the doctor's address to the patient's authorizedDoctors array
        users[msg.sender].authorizedDoctors.push(_doctorAddress);

        // Add the patient's address to the doctor's authorizedPatients array
        users[_doctorAddress].authorizedPatients.push(msg.sender);

        // Emit an event indicating permission has been granted
        emit PermissionGranted(msg.sender, _doctorAddress);

        return _doctorAddress;
    }

    // Function to check if a doctor is already authorized by the patient
    function isDoctorAuthorized(address _doctorAddress) internal view returns (bool) {
        for (uint256 i = 0; i < users[msg.sender].authorizedDoctors.length; i++) {
            if (users[msg.sender].authorizedDoctors[i] == _doctorAddress) {
                return true;
            }
        }
        return false;
    }

    function uploadMedicalRecord(address _patientAddress, string memory _recordHash) external {
        require(users[msg.sender].role == Role.Doctor, "Only doctors can upload medical records");
        require(users[_patientAddress].authorizedPatients.length > 0, "Doctor is not authorized to upload records for this patient");
        users[_patientAddress].medicalRecords[msg.sender].push(_recordHash);
        emit MedicalRecordUploaded(msg.sender, _patientAddress, _recordHash);
    }


    function getMedicalRecords(address _patientAddress) external view returns (string[] memory) {
        require(users[msg.sender].role == Role.Patient, "Only patients can view medical records");
        require(msg.sender == _patientAddress, "You can only view your own medical records");
        return users[_patientAddress].medicalRecords[msg.sender];
    }

    function getAuthorizedDoctors() external view returns (address[] memory) {
        require(users[msg.sender].role == Role.Patient, "Only patients can access this function");

        // Return the list of authorized doctors for the caller
        return users[msg.sender].authorizedDoctors;
    }
    
    function getAllDoctors() external view returns (address[] memory, string[] memory) {
        require(users[msg.sender].role == Role.Patient, "Only patients can access this function");

        // Get the list of all doctors
        string[] memory doctorNames = new string[](allDoctors.length);
        for(uint i = 0; i < allDoctors.length; i++) {
            doctorNames[i] = users[allDoctors[i]].name;
        }
        return (allDoctors, doctorNames);
    }
}
