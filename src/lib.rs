use zed_extension_api as zed;

struct EnmaExtension {

}

impl zed::Extension for EnmaExtension {
    fn new() -> Self
    where
        Self: Sized {
        todo!()
    }
}

zed::register_extension!(EnmaExtension);
