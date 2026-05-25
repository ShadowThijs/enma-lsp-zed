use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Deserialize)]
pub struct MethodInfo {
    #[serde(alias = "n")]
    pub name: String,
    #[serde(alias = "p", default)]
    pub params: Vec<ParamInfo>,
    #[serde(alias = "r")]
    pub r#return: String,
    #[serde(default)]
    pub doc: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ParamInfo {
    #[serde(alias = "n")]
    pub name: String,
    #[serde(alias = "t")]
    pub r#type: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct FreeFunction {
    #[serde(alias = "n")]
    pub name: String,
    #[serde(alias = "p", default)]
    pub params: Vec<ParamInfo>,
    #[serde(alias = "r")]
    pub r#return: String,
    #[serde(default)]
    pub doc: String,
    #[serde(alias = "m", default)]
    pub module: String,
    #[serde(default)]
    pub variadic: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct MathType {
    #[serde(default)]
    pub fields: Vec<String>,
    #[serde(alias = "methods", default)]
    pub methods: Vec<MethodInfo>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ComplexType {
    #[serde(default)]
    pub doc: String,
    #[serde(alias = "methods", default)]
    pub methods: Vec<MethodInfo>,
    #[serde(alias = "free_functions", default)]
    pub free_functions: Vec<FreeFunction>,
}

#[derive(Debug, Clone, Deserialize)]
struct TypeDataFile {
    #[serde(default)]
    keyword_types: Vec<String>,
    #[serde(default)]
    primitives: HashMap<String, serde_json::Value>,
    #[serde(default)]
    types: HashMap<String, ComplexType>,
    #[serde(default)]
    free_functions: Vec<FreeFunction>,
    #[serde(default)]
    math_types: HashMap<String, MathType>,
}

pub struct TypeDatabase {
    pub types: HashMap<String, Vec<MethodInfo>>,
    pub math_types: HashMap<String, MathType>,
    pub functions: HashMap<String, FreeFunction>,
    pub module_functions: HashMap<String, Vec<FreeFunction>>,
    pub primitive_names: Vec<String>,
    pub keywords: Vec<String>,
    pub all_type_names: Vec<String>,
}

impl TypeDatabase {
    pub fn load() -> Self {
        let json = include_str!("types.json");
        let data: TypeDataFile = serde_json::from_str(json)
            .expect("Failed to parse types.json");

        let mut types: HashMap<String, Vec<MethodInfo>> = HashMap::new();
        let mut functions: HashMap<String, FreeFunction> = HashMap::new();
        let mut module_functions: HashMap<String, Vec<FreeFunction>> = HashMap::new();
        let mut all_type_names: Vec<String> = Vec::new();

        let primitive_names: Vec<String> = data.primitives.keys().cloned().collect();
        all_type_names.extend(primitive_names.clone());

        for (name, ct) in &data.types {
            types.insert(name.clone(), ct.methods.clone());
            all_type_names.push(name.clone());
            for ff in &ct.free_functions {
                functions.insert(ff.name.clone(), ff.clone());
                module_functions.entry(ff.module.clone()).or_default().push(ff.clone());
            }
        }

        let math_types = data.math_types;
        for name in math_types.keys() {
            all_type_names.push(name.clone());
        }

        for ff in &data.free_functions {
            functions.insert(ff.name.clone(), ff.clone());
            module_functions.entry(ff.module.clone()).or_default().push(ff.clone());
        }

        Self {
            types,
            math_types,
            functions,
            module_functions,
            primitive_names,
            keywords: data.keyword_types,
            all_type_names,
        }
    }

    pub fn get_methods(&self, type_name: &str) -> Option<&Vec<MethodInfo>> {
        self.types.get(type_name).or_else(|| self.math_types.get(type_name).map(|m| &m.methods))
    }

    pub fn get_fields(&self, type_name: &str) -> Option<&Vec<String>> {
        self.math_types.get(type_name).map(|m| &m.fields)
    }

    pub fn is_type(&self, name: &str) -> bool {
        self.all_type_names.contains(&name.to_string())
    }

    pub fn is_primitive(&self, name: &str) -> bool {
        self.primitive_names.contains(&name.to_string())
    }

    pub fn method_detail(m: &MethodInfo) -> String {
        let params: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
        format!("{}({}) -> {}", m.name, params.join(", "), m.r#return)
    }

    pub fn function_detail(f: &FreeFunction) -> String {
        let params: Vec<String> = f.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
        let suffix = if f.variadic { ", ..." } else { "" };
        format!("{}({}{}) -> {}", f.name, params.join(", "), suffix, f.r#return)
    }
}
