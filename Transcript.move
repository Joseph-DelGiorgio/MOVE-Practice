module myModule::myModule{
    
    use sui::object::{UID};

    struct TranscriptObject has key {
        id: UID,
        history: u8,
        math: u8,
        literature: u8,
    }

    use sui::object::{Self};
    use sui:: tx_context::{Self, TxContext};
    use sui::transfer;

    public fun create_transcript_object(history: u8, math: u8, literature: u8, ctx: &mut TxContext ){
        let transcriptObject = TranscriptObject{
            id: object::new(ctx),
            history,
            math,
            literature,
        };
        transfer::transfer(transcriptObject, tx_context::sender(ctx))
    }

    use sui::object::{Self};

    // You are allowed to retrieve the score but cannot modify it
    public fun view_score(transcriptObject: &TranscriptObject): u8{
        transcriptObject.literature
    }

    // You are allowed to view and edit the score but not allowed to delete it
    public fun update_score(transcriptObject: &mut TranscriptObject, score: u8){
        transcriptObject.literature = score
    }

    // You are allowed to do anything with the score, including view, edit, or delete the entire transcript itself.
    public fun delete_transcript(transcriptObject: TranscriptObject){
        let TranscriptObject {id, history: _, math: _, literature: _ } = transcriptObject;
        object::delete(id);
    }

    public struct WrappableTranscript has key, store {
        id: UID,
        history: u8,
        math: u8,
        literature: u8,
    }

    public struct Folder has key{
        id: UID,
        transcript: WrappableTranscript,
        intended_address: address
    }

    public fun request_transcript(transcript: WrappableTranscript, intended_address: address, ctx: &mut TxContext){
        let folderObject = Folder {
            id: object::new(ctx),
            transcript,
            intended_address
        };
        //We transfer the wrapped transcript object directly to the intended address
        transfer::transfer(folderObject, intended_address)

    }

    public fun unpack_wrapped_transcript(folder: Folder, ctx: &mut TxContext){
        // Check that the person unpacking the transcript is the intended viewer
        assert!(folder.intended_address == tx_context::sender(ctx), 0);
        let Folder {
            id,
            transcript,
            intended_address:_,
        } = folder;
        transfer::transfer(transcript, tx_context::sender(ctx));
        // Deletes the wrapper Folder object
        object::delete(id)
    }
}
