require_relative('../spec_helper')

describe RubyCqrs::Data::InMemoryEventStore do
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  let(:change_set_1) {}
  let(:change_set_2) {}
  let(:command_context) {}

  describe '#save' do
    it 'saved' do
      event_store.save change_set_1, command_context
    end
  end

  describe '#load_by' do
    it 'loaded' do
      expect(true).to be(true)
    end
  end

end
