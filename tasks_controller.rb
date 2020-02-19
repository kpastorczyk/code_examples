module Api
  module V1
    class TasksController < Api::BaseController
      api :GET, 'api/v1/tasks', 'Get all tasks'
      param :task_type, String
      param :user_code, String
      param :store_code, String
      param :page, Integer
      def index
        tasks = TasksForUserQuery.new(current_user, filter_attributes).call

        render(
          json: tasks,
          products_from_brandbank: products_from_brandbank_for(tasks),
          brands_from_brandbank: brands_from_brandbank_for(tasks),
          each_serializer: Api::TaskSerializer
        )
      end

      api :POST, 'api/v1/tasks', 'Create task'
      param :task_code, String
      param :task_type, String
      param :name, String
      param :products_category, String
      param :products, Array
      def create
        @task_service = Tasks::Create.new(params.merge(customer_id: current_user.customer_id)).call
        if @task_service.success?
          render json: @task_service.value!, with: Api::TaskSerializer
        else
          render json: { error: @task_service.failure }, status: :unprocessable_entity
        end
      end

      private

      def filter_attributes
        {
          task_type: params[:task_type],
          outlet_id: params[:store_code],
          page: params[:page],
        }.compact
      end

      def products_from_brandbank_for(tasks)
        product_ids = tasks.map(&:client_product_ids) + tasks.map(&:competition_product_ids)
        BbMeta::Products.new.by_ids(
          product_ids.compact.flatten.uniq,
          context: BrandbankMetadata.default_context
        ).data
      end

      def brands_from_brandbank_for(tasks)
        brand_ids = tasks.map(&:client_brand_ids) + tasks.map(&:competition_brand_ids)
        BbMeta::Brands.new.by_ids(brand_ids.compact.flatten.uniq).data
      end
    end
  end
end
