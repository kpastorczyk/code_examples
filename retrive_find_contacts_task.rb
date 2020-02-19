module Services
  module ContactResearch
    class RetriveFindContactsTask
      def initialize(find_contacts_task_db, customer_db)
        @find_contacts_task_db = find_contacts_task_db
        @customer_db = customer_db
      end

      def call(customer_id)
        customer = @customer_db.fetch(customer_id)
        find_contacts_tasks = @find_contacts_task_db.fetch_all_looking_for_emails_tasks_for(customer.id)
        find_contacts_tasks.each do |find_contacts_task|
          find_contacts_task.set_opened_for_emails_status
          @find_contacts_task_db.save(find_contacts_task)
        end
      end
    end
  end
end
