module TaskManagementSystem {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::String;
    use 0x1::Event;

    struct Task {
        id: u64,
        creator: address,
        assignee: address,
        description: String,
        completed: bool,
    }

    struct TaskManagementSystem {
        tasks: vector<Task>,
        next_task_id: u64,
    }

    event TaskCreatedEvent {
        task_id: u64,
        creator: address,
        assignee: address,
        description: String,
    }

    event TaskCompletedEvent {
        task_id: u64,
        assignee: address,
    }

    public fun new_task_management_system(admin: &signer): address {
        let task_management_system = TaskManagementSystem {
            tasks: vector::empty(),
            next_task_id: 0,
        };
        let task_management_system_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, task_management_system);
        task_management_system_address
    }

    public fun create_task(task_management_system_address: address, creator: &signer, assignee: address, description: String) {
        let creator_address = Signer::address_of(creator);
        let task_management_system = &mut borrow_global_mut<TaskManagementSystem>(task_management_system_address);

        let task = Task {
            id: task_management_system.next_task_id,
            creator: creator_address,
            assignee,
            description,
            completed: false,
        };

        task_management_system.next_task_id += 1;
        vector::push_back(&mut task_management_system.tasks, task);

        Event::emit<TaskCreatedEvent>(TaskCreatedEvent {
            task_id: task.id,
            creator: creator_address,
            assignee,
            description,
        });
    }

    public fun complete_task(task_management_system_address: address, assignee: &signer, task_id: u64) {
        let assignee_address = Signer::address_of(assignee);
        let task_management_system = &mut borrow_global_mut<TaskManagementSystem>(task_management_system_address);
        let task = &mut find_task_mut(&mut task_management_system.tasks, task_id);

        assert!(task.assignee == assignee_address, Errors::invalid_argument(1));
        assert!(!task.completed, Errors::invalid_argument(2));

        task.completed = true;

        Event::emit<TaskCompletedEvent>(TaskCompletedEvent {
            task_id: task.id,
            assignee: assignee_address,
        });
    }

    public fun get_tasks(task_management_system_address: address): vector<(u64, address, address, String, bool)> {
        let task_management_system = borrow_global<TaskManagementSystem>(task_management_system_address);
        let mut task_list: vector<(u64, address, address, String, bool)> = vector::empty();

        for task in &task_management_system.tasks {
            vector::push_back(
                &mut task_list,
                (task.id, task.creator, task.assignee, task.description, task.completed),
            );
        }

        task_list
    }

    fun find_task(tasks: &vector<Task>, id: u64): &Task {
        let task_opt = vector::find(tasks, move |task| task.id == id);
        assert!(task_opt.is_some(), Errors::not_found(0));
        task_opt.borrow().unwrap()
    }

    fun find_task_mut(tasks: &mut vector<Task>, id: u64): &mut Task {
        let task_opt = vector::find_mut(tasks, move |task| task.id == id);
        assert!(task_opt.is_some(), Errors::not_found(0));
        task_opt.borrow_mut().unwrap()
    }
}
