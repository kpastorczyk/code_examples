require 'rails_helper'

RSpec.describe Api::V1::TasksController do
  include Helpers::AuthenticationMock

  let!(:customer) { FactoryBot.create(:customer) }
  let!(:password) { 'example_password' }
  let(:timestamp) { Time.now.to_i }
  let(:request_signature) { SecureRandom.hex(10) }
  let!(:user) do
    FactoryBot.create(:user, password: password, password_confirmation: password, customer: customer)
  end

  let!(:outlet) { FactoryBot.create(:outlet, customer: customer) }
  let!(:user_outlet) { FactoryBot.create(:user_outlet, outlet: outlet, user: user) }
  let!(:task) { FactoryBot.create(:task, client_product_ids: [product.id], client_brand_ids: [brand.id]) }
  let!(:task_oos) { FactoryBot.create(:task, :oos, client_product_ids: [product.id]) }
  let!(:group_task) { FactoryBot.create(:group_task) }
  let!(:role) { FactoryBot.create(:rule, group_task: group_task, shop: nil, city: nil, area: nil) }
  let!(:task_group_task) { FactoryBot.create(:task_group_task, task: task, group_task: group_task) }
  let!(:task_group_task_oos) { FactoryBot.create(:task_group_task, task: task_oos, group_task: group_task) }
  let(:product_attrs) { FactoryBot.attributes_for(:brand_bank_product) }
  let(:category_attrs) { FactoryBot.attributes_for(:brand_bank_category) }
  let(:brand_attrs) { FactoryBot.attributes_for(:brand_bank_brand) }
  let(:product) { BbMeta::Product.new(product_attrs) }
  let(:category) { BbMeta::Category.new(category_attrs) }
  let(:brand) { BbMeta::Brand.new(brand_attrs) }
  let(:expected_tasks_json) do
  end

  before do
    request.headers['Authorization'] = "#{user.api_access_key}:#{request_signature_hash}"
    request.headers['X-Timestamp'] = timestamp

    allow(BbMeta::Products).to receive_message_chain(:new, :by_ids) do
      instance_double(BbMetaCollectionFacade, data: [product])
    end

    allow(BbMeta::Products).to receive_message_chain(:new, :all) do
      instance_double(BbMetaCollectionFacade, data: [product])
    end

    allow(BbMeta::Brands).to receive_message_chain(:new, :by_ids) do
      instance_double(BbMetaCollectionFacade, data: [brand])
    end

    allow(BbMeta::Categories).to receive_message_chain(:new, :all) do
      instance_double(BbMetaCollectionFacade, data: [category])
    end
  end

  describe '#index' do
    let(:request_signature_hash) do
      ::RequestSignature.new(user.api_secret_key, timestamp, 'GET', '/api/v1/tasks').call
    end

    context 'with authenticated user' do
      it 'return two tasks with proper structure' do
        get :index
        expect(response).to be_successful
        expect(JSON.parse(response.body).size).to eq(2)
        expect(JSON.parse(response.body).first.keys).to include('task_id', 'task_type', 'products_category', 'products')
        expect(JSON.parse(response.body)).to match(a_hash_including(
                                                     'task_id' => task_oos.id.to_s,
                                                     'task_code' => '',
                                                     'task_type' => 'out_of_stock',
                                                     'products_category' => task.category_id.to_s,
                                                     'products' => [
                                                       { 'ean' => product.ean }
                                                     ]
                                                   ))
      end

      it 'return only one task' do
        get :index, params: { task_type: 'out_of_stock' }
        expect(JSON.parse(response.body).size).to eq(1)
        expect(JSON.parse(response.body).first['task_type']).to eq('out_of_stock')
      end
    end
  end

  describe '#create' do
    let(:request_signature_hash) do
      ::RequestSignature.new(user.api_secret_key, timestamp, 'POST', '/api/v1/tasks', params.to_query).call
    end

    context 'with valid params user' do
      let(:params) do
        {
          "task_code": Faker::Code.npi,
          "task_type": Task::TASK_TYPE_OUT_OF_STOCK,
          "name": Faker::Name.name,
          "products_category": category.name,
          "products": [
            { "ean": product.ean }
          ]
        }
      end

      it 'create task' do
        post :create, params: params.to_h

        expect(response).to be_successful
      end
    end

    context 'with invalid params user' do
      let(:params) do
        {
          "task_code": 'Product123',
        }
      end

      it 'return error message' do
        post :create, params: params.to_h

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
