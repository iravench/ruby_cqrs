require_relative('../spec_helper')
describe 'decoder & encoder' do
  let(:unsupported_obj) { SomeDomain::FirstEvent.new }
  let(:unsupported_obj_type) { SomeDomain::FirstEvent.name }
  let(:supported_obj) { SomeDomain::THIRD_EVENT_INSTANCE }
  let(:supported_obj_type) { SomeDomain::THIRD_EVENT_INSTANCE.class.name }

  describe RubyCqrs::Data::Encodable do
    describe '#try_encode' do
      it 'encodes a supported object into string' do
        encoded_message = supported_obj.try_encode
        expect(encoded_message.class.name).to eq('String')
      end

      it 'returns an unsupported object as is' do
        encoded_message = unsupported_obj.try_encode
        expect(encoded_message.class.name).to eq(unsupported_obj_type)
      end
    end
  end

  describe RubyCqrs::Data::Decodable do
    let(:decoder_type) { Class.new { include RubyCqrs::Data::Decodable } }
    let(:decoder) { decoder_type.new }

    describe '#try_decode' do
      let(:unsupported_record) {
        { :object_type => unsupported_obj_type,
          :data => unsupported_obj } }
      let(:supported_record) {
        { :object_type => supported_obj_type,
          :data => supported_obj.try_encode } }

      it 'decodes a supported object type from string' do
        decoded_object = decoder.try_decode(supported_record[:object_type],\
                                           supported_record[:data])
        expect(decoded_object.class.name).to eq(supported_obj_type)
        # specific test value
        expect(decoded_object.id).to eq(1)
        expect(decoded_object.name).to eq('some dude')
        expect(decoded_object.phone).to eq('13322244444')
        expect(decoded_object.note).to eq('good luck')
      end

      it 'returns as is for an unsupported object type' do
        decoded_object = decoder.try_decode(unsupported_record[:object_type],\
                                           unsupported_record[:data])
        expect(decoded_object.class.name).to eq(unsupported_obj_type)
      end
    end
  end
end
