require_relative('../spec_helper')

describe RubyCqrs::Data::ProtobufableEvent do
  let(:store_type) { Class.new { include RubyCqrs::Data::ProtobufableEvent } }
  let(:store) { store_type.new }

  describe '#try_encode' do
    let(:unsupported_event) { SomeDomain::FirstEvent.new }
    let(:supported_event) { SomeDomain::THIRD_EVENT_INSTANCE }

    it 'encodes a supported event into string' do
      encoded_message = store.try_encode supported_event
      expect(encoded_message.class.name).to eq('String')
    end

    it 'returns an unsupported event as is' do
      encoded_message = store.try_encode unsupported_event
      expect(encoded_message.class.name).to eq('SomeDomain::FirstEvent')
    end
  end

  describe '#try_decode' do
    let(:unsupported_event_record) { { :aggregate_id => SomeDomain::AGGREGATE_ID,
                                       :event_type => 'SomeDomain::FirstEvent',
                                       :version => 1,
                                       :data => SomeDomain::FirstEvent.new } }
    let(:supported_event_record) { {   :aggregate_id => SomeDomain::AGGREGATE_ID,
                                       :event_type => 'SomeDomain::ThirdEvent',
                                       :version => 1,
                                       :data => store.try_encode(SomeDomain::THIRD_EVENT_INSTANCE) } }

    it 'decodes a supported event type from string' do
      decoded_event = store.try_decode supported_event_record
      expect(decoded_event.class.name).to eq('SomeDomain::ThirdEvent')
      expect(decoded_event.aggregate_id).to eq(SomeDomain::AGGREGATE_ID)
      expect(decoded_event.version).to eq(1)
    end

    it 'returns as is for an unsupported event type' do
      decoded_event = store.try_decode unsupported_event_record
      expect(decoded_event.class.name).to eq('SomeDomain::FirstEvent')
    end
  end
end
