module FreelanceJobMarketplace {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::String;
    use 0x1::Coin;
    use 0x1::Event;

    struct Job {
        id: u64,
        client: address,
        title: String,
        description: String,
        budget: u64,
        deadline: u64,
        assigned_freelancer: option<address>,
        status: u8, // 0: open, 1: assigned, 2: completed
    }

    struct Application {
        job_id: u64,
        freelancer: address,
        proposal: String,
    }

    struct FreelanceJobMarketplace {
        jobs: vector<Job>,
        applications: vector<Application>,
        next_job_id: u64,
    }

    event JobPostedEvent {
        job_id: u64,
        client: address,
        title: String,
        description: String,
        budget: u64,
        deadline: u64,
    }

    event JobAppliedEvent {
        job_id: u64,
        freelancer: address,
        proposal: String,
    }

    event JobAssignedEvent {
        job_id: u64,
        freelancer: address,
    }

    event JobCompletedEvent {
        job_id: u64,
    }

    public fun new_job_marketplace(admin: &signer): address {
        let marketplace = FreelanceJobMarketplace {
            jobs: vector::empty(),
            applications: vector::empty(),
            next_job_id: 0,
        };
        let marketplace_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, marketplace);
        marketplace_address
    }

    public fun post_job(marketplace_address: address, client: &signer, title: String, description: String, budget: u64, deadline: u64) {
        let client_address = Signer::address_of(client);
        let marketplace = &mut borrow_global_mut<FreelanceJobMarketplace>(marketplace_address);

        let job = Job {
            id: marketplace.next_job_id,
            client: client_address,
            title,
            description,
            budget,
            deadline,
            assigned_freelancer: option::none(),
            status: 0,
        };

        marketplace.next_job_id += 1;
        vector::push_back(&mut marketplace.jobs, job);

        Event::emit<JobPostedEvent>(JobPostedEvent {
            job_id: job.id,
            client: client_address,
            title: job.title,
            description: job.description,
            budget: job.budget,
            deadline: job.deadline,
        });
    }

    public fun apply_for_job(marketplace_address: address, freelancer: &signer, job_id: u64, proposal: String) {
        let freelancer_address = Signer::address_of(freelancer);
        let marketplace = &mut borrow_global_mut<FreelanceJobMarketplace>(marketplace_address);
        let job = &find_job(&marketplace.jobs, job_id);

        assert!(job.status == 0, Errors::invalid_argument(1)); // Ensure job is open

        let application = Application {
            job_id: job_id,
            freelancer: freelancer_address,
            proposal,
        };

        vector::push_back(&mut marketplace.applications, application);

        Event::emit<JobAppliedEvent>(JobAppliedEvent {
            job_id: job_id,
            freelancer: freelancer_address,
            proposal: application.proposal,
        });
    }

    public fun assign_job(marketplace_address: address, client: &signer, job_id: u64, freelancer_address: address) {
        let client_address = Signer::address_of(client);
        let marketplace = &mut borrow_global_mut<FreelanceJobMarketplace>(marketplace_address);
        let job = &mut find_job_mut(&mut marketplace.jobs, job_id);

        assert!(job.client == client_address, Errors::invalid_argument(2)); // Ensure client is assigning their own job
        assert!(job.status == 0, Errors::invalid_argument(3)); // Ensure job is open

        job.assigned_freelancer = option::some(freelancer_address);
        job.status = 1;

        Event::emit<JobAssignedEvent>(JobAssignedEvent {
            job_id: job.id,
            freelancer: freelancer_address,
        });
    }

    public fun complete_job(marketplace_address: address, freelancer: &signer, job_id: u64) {
        let freelancer_address = Signer::address_of(freelancer);
        let marketplace = &mut borrow_global_mut<FreelanceJobMarketplace>(marketplace_address);
        let job = &mut find_job_mut(&mut marketplace.jobs, job_id);

        assert!(job.assigned_freelancer == option::some(freelancer_address), Errors::invalid_argument(4)); // Ensure correct freelancer
        assert!(job.status == 1, Errors::invalid_argument(5)); // Ensure job is assigned

        job.status = 2;

        Coin::transfer(&borrow_global<SUI>(freelancer_address), job.client, job.budget);

        Event::emit<JobCompletedEvent>(JobCompletedEvent {
            job_id: job.id,
        });
    }

    public fun get_jobs(marketplace_address: address): vector<(u64, address, String, String, u64, u64, u8)> {
        let marketplace = borrow_global<FreelanceJobMarketplace>(marketplace_address);
        let mut job_list: vector<(u64, address, String, String, u64, u64, u8)> = vector::empty();

        for job in &marketplace.jobs {
            vector::push_back(
                &mut job_list,
                (job.id, job.client, job.title, job.description, job.budget, job.deadline, job.status),
            );
        }

        job_list
    }

    fun find_job(jobs: &vector<Job>, id: u64): &Job {
        let job_opt = vector::find(jobs, move |job| job.id == id);
        assert!(job_opt.is_some(), Errors::not_found(0));
        job_opt.borrow().unwrap()
    }

    fun find_job_mut(jobs: &mut vector<Job>, id: u64): &mut Job {
        let job_opt = vector::find_mut(jobs, move |job| job.id == id);
        assert!(job_opt.is_some(), Errors::not_found(0));
        job_opt.borrow_mut().unwrap()
    }
}

/*
Pseudo Code
Structures

Job

id: integer
client: address
title: string
description: string
budget: integer
deadline: integer
assigned_freelancer: optional address
status: integer (0: open, 1: assigned, 2: completed)
Application

job_id: integer
freelancer: address
proposal: string
FreelanceJobMarketplace

jobs: list of Job
applications: list of Application
next_job_id: integer
Events

JobPostedEvent

job_id: integer
client: address
title: string
description: string
budget: integer
deadline: integer
JobAppliedEvent

job_id: integer
freelancer: address
proposal: string
JobAssignedEvent

job_id: integer
freelancer: address
JobCompletedEvent

job_id: integer
Functions

new_job_marketplace(admin): address

Initialize FreelanceJobMarketplace with empty lists for jobs and applications.
Set next_job_id to 0.
Create a new resource account and return its address.
post_job(marketplace_address, client, title, description, budget, deadline)

Retrieve the marketplace instance.
Create a new Job with provided details and assigned_freelancer as none.
Increment next_job_id.
Add the new job to the jobs list.
Emit JobPostedEvent.
apply_for_job(marketplace_address, freelancer, job_id, proposal)

Retrieve the marketplace instance.
Retrieve the job using job_id.
Ensure the job status is open.
Create a new Application with provided details.
Add the application to the applications list.
Emit JobAppliedEvent.
assign_job(marketplace_address, client, job_id, freelancer_address)

Retrieve the marketplace instance.
Retrieve the job using job_id.
Ensure the client is the job's client.
Ensure the job status is open.
Set assigned_freelancer to freelancer_address and change status to assigned.
Emit JobAssignedEvent.
complete_job(marketplace_address, freelancer, job_id)

Retrieve the marketplace instance.
Retrieve the job using job_id.
Ensure the freelancer is the assigned freelancer.
Ensure the job status is assigned.
Change job status to completed.
Transfer the budget from the client to the freelancer.
Emit JobCompletedEvent.
get_jobs(marketplace_address)

Retrieve the marketplace instance.
Return the list of all jobs with their details.
find_job(jobs, id)

Find and return the job with the given ID.
find_job_mut(jobs, id)

Find and return a mutable reference to the job with the given ID.
Example Workflow
Client posts a job

Client calls post_job with job details.
New job is added to the marketplace.
JobPostedEvent is emitted.
Freelancer applies for a job

Freelancer calls apply_for_job with job ID and proposal.
New application is added to the marketplace.
JobAppliedEvent is emitted.
Client assigns the job to a freelancer

Client calls assign_job with job ID and freelancer address.
Job status is updated to assigned.
JobAssignedEvent is emitted.
Freelancer completes the job

Freelancer calls complete_job with job ID.
Job status is updated to completed.
Budget is transferred to the freelancer.
JobCompletedEvent is emitted.

*/
