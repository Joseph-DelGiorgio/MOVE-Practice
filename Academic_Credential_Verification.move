module AcademicCredentialVerification {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::String;
    use 0x1::Event;

    struct Credential {
        id: u64,
        institution: address,
        student: address,
        degree: String,
        major: String,
        date_issued: u64,
    }

    struct AcademicCredentialVerification {
        credentials: vector<Credential>,
        next_credential_id: u64,
    }

    event CredentialIssuedEvent {
        credential_id: u64,
        institution: address,
        student: address,
        degree: String,
        major: String,
        date_issued: u64,
    }

    event CredentialClaimedEvent {
        credential_id: u64,
        student: address,
    }

    public fun new_credential_system(admin: &signer): address {
        let credential_system = AcademicCredentialVerification {
            credentials: vector::empty(),
            next_credential_id: 0,
        };
        let credential_system_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, credential_system);
        credential_system_address
    }

    public fun issue_credential(credential_system_address: address, institution: &signer, student: address, degree: String, major: String, date_issued: u64) {
        let institution_address = Signer::address_of(institution);
        let credential_system = &mut borrow_global_mut<AcademicCredentialVerification>(credential_system_address);

        let credential = Credential {
            id: credential_system.next_credential_id,
            institution: institution_address,
            student,
            degree,
            major,
            date_issued,
        };

        credential_system.next_credential_id += 1;
        vector::push_back(&mut credential_system.credentials, credential);

        Event::emit<CredentialIssuedEvent>(CredentialIssuedEvent {
            credential_id: credential.id,
            institution: institution_address,
            student,
            degree: credential.degree,
            major: credential.major,
            date_issued: credential.date_issued,
        });
    }

    public fun claim_credential(credential_system_address: address, student: &signer, credential_id: u64) {
        let student_address = Signer::address_of(student);
        let credential_system = &mut borrow_global_mut<AcademicCredentialVerification>(credential_system_address);
        let credential = &mut find_credential_mut(&mut credential_system.credentials, credential_id);

        assert!(credential.student == student_address, Errors::invalid_argument(1));

        Event::emit<CredentialClaimedEvent>(CredentialClaimedEvent {
            credential_id: credential.id,
            student: student_address,
        });
    }

    public fun verify_credential(credential_system_address: address, credential_id: u64): (address, address, String, String, u64) {
        let credential_system = borrow_global<AcademicCredentialVerification>(credential_system_address);
        let credential = &find_credential(&credential_system.credentials, credential_id);

        (credential.institution, credential.student, credential.degree, credential.major, credential.date_issued)
    }

    fun find_credential(credentials: &vector<Credential>, id: u64): &Credential {
        let credential_opt = vector::find(credentials, move |credential| credential.id == id);
        assert!(credential_opt.is_some(), Errors::not_found(0));
        credential_opt.borrow().unwrap()
    }

    fun find_credential_mut(credentials: &mut vector<Credential>, id: u64): &mut Credential {
        let credential_opt = vector::find_mut(credentials, move |credential| credential.id == id);
        assert!(credential_opt.is_some(), Errors::not_found(0));
        credential_opt.borrow_mut().unwrap()
    }
}
