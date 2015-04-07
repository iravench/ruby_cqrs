require_relative('../spec_helper')

describe RubyCqrs::Data::Encodable do
  describe '#try_encode' do
    let(:unsupported_event) { SomeDomain::FirstEvent.new }
    let(:supported_event) { SomeDomain::THIRD_EVENT_INSTANCE }

    it 'encodes a supported event into string' do
      encoded_message = supported_event.try_encode
      expect(encoded_message.class.name).to eq('String')
    end

    it 'returns an unsupported event as is' do
      encoded_message = unsupported_event.try_encode
      expect(encoded_message.class.name).to eq('SomeDomain::FirstEvent')
    end
  end
end

describe RubyCqrs::Data::Decodable do
  let(:decoder_type) { Class.new { include RubyCqrs::Data::Decodable } }
  let(:decoder) { decoder_type.new }

  describe '#try_decode' do
    let(:unsupported_event_record) { { :aggregate_id => SomeDomain::AGGREGATE_ID,
                                       :event_type => 'SomeDomain::FirstEvent',
                                       :version => 1,
                                       :data => SomeDomain::FirstEvent.new } }
    let(:supported_event_record) { {   :aggregate_id => SomeDomain::AGGREGATE_ID,
                                       :event_type => 'SomeDomain::ThirdEvent',
                                       :version => 1,
                                       :data => SomeDomain::THIRD_EVENT_INSTANCE.try_encode } }

    it 'decodes a supported event type from string' do
      decoded_event = decoder.try_decode(supported_event_record[:event_type],\
                                         supported_event_record[:data])
      expect(decoded_event.class.name).to eq('SomeDomain::ThirdEvent')
      expect(decoded_event.id).to eq(1)
      expect(decoded_event.name).to eq('some dude')
      expect(decoded_event.phone).to eq('13322244444')
      expect(decoded_event.note).to eq('good luck')
    end

    it 'returns as is for an unsupported event type' do
      decoded_event = decoder.try_decode(unsupported_event_record[:event_type],\
                                         unsupported_event_record[:data])
      expect(decoded_event.class.name).to eq('SomeDomain::FirstEvent')
    end
  end
end
