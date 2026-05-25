use serde::Deserialize;
use std::collections::HashMap;

/// A single method on a type.
#[derive(Debug, Clone, Deserialize)]
pub struct MethodInfo {
    pub name: String,
    pub params: Vec<ParamInfo>,
    pub r#return: String,
    #[serde(default)]
    pub doc: String,
}

/// A parameter of a method.
#[derive(Debug, Clone, Deserialize)]
pub struct ParamInfo {
    pub name: String,
    pub r#type: String,
}

/// A top-level free function.
#[derive(Debug, Clone, Deserialize)]
pub struct FreeFunction {
    pub name: String,
    pub params: Vec<ParamInfo>,
    pub r#return: String,
    #[serde(default)]
    pub doc: String,
    #[serde(default)]
    pub module: String,
    #[serde(default)]
    pub variadic: bool,
}

/// A math/struct type with fields and methods.
#[derive(Debug, Clone, Deserialize)]
pub struct MathType {
    #[serde(default)]
    pub fields: Vec<String>,
    #[serde(default)]
    pub methods: Vec<MethodInfo>,
}

/// A complex type with methods and optional free functions.
#[derive(Debug, Clone, Deserialize)]
pub struct ComplexType {
    #[serde(default)]
    pub doc: String,
    #[serde(default)]
    pub methods: Vec<MethodInfo>,
    #[serde(default)]
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

/// The loaded, indexed type database.
pub struct TypeDatabase {
    /// All known type names → their methods
    pub types: HashMap<String, Vec<MethodInfo>>,
    /// Math/struct types → fields + methods
    pub math_types: HashMap<String, MathType>,
    /// All free functions indexed by name
    pub functions: HashMap<String, FreeFunction>,
    /// Free functions organized by module
    pub module_functions: HashMap<String, Vec<FreeFunction>>,
    /// All primitive type names
    pub primitive_names: Vec<String>,
    /// All keyword tokens
    pub keywords: Vec<String>,
    /// All type names (primitives + complex + math) for completion
    pub all_type_names: Vec<String>,
}

impl TypeDatabase {
    /// Load the type database from the embedded types.json.
    pub fn load() -> Self {
        let json = include_str!("types.json");
        let data: TypeDataFile = serde_json::from_str(json)
            .expect("Failed to parse types.json");

        let mut types: HashMap<String, Vec<MethodInfo>> = HashMap::new();
        let mut functions: HashMap<String, FreeFunction> = HashMap::new();
        let mut module_functions: HashMap<String, Vec<FreeFunction>> = HashMap::new();
        let mut all_type_names: Vec<String> = Vec::new();

        // Primitive type names
        let primitive_names: Vec<String> = data.primitives.keys().cloned().collect();
        all_type_names.extend(primitive_names.clone());

        // Complex types
        for (name, ct) in &data.types {
            types.insert(name.clone(), ct.methods.clone());
            all_type_names.push(name.clone());
            for ff in &ct.free_functions {
                functions.insert(ff.name.clone(), ff.clone());
                module_functions
                    .entry(ff.module.clone())
                    .or_default()
                    .push(ff.clone());
            }
        }

        let math_types = data.math_types;
        for name in math_types.keys() {
            all_type_names.push(name.clone());
        }

        // Global free functions
        for ff in &data.free_functions {
            functions.insert(ff.name.clone(), ff.clone());
            module_functions
                .entry(ff.module.clone())
                .or_default()
                .push(ff.clone());
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

    /// Get methods for a given type name.
    pub fn get_methods(&self, type_name: &str) -> Option<&Vec<MethodInfo>> {
        self.types
            .get(type_name)
            .or_else(|| self.math_types.get(type_name).map(|m| &m.methods))
    }

    /// Get fields for a given math/struct type.
    pub fn get_fields(&self, type_name: &str) -> Option<&Vec<String>> {
        self.math_types.get(type_name).map(|m| &m.fields)
    }

    /// Check if a name is a known type.
    pub fn is_type(&self, name: &str) -> bool {
        self.all_type_names.contains(&name.to_string())
    }

    /// Check if a name is a primitive type.
    pub fn is_primitive(&self, name: &str) -> bool {
        self.primitive_names.contains(&name.to_string())
    }

    /// Build a detail string for a method signature.
    pub fn method_detail(m: &MethodInfo) -> String {
        let params: Vec<String> = m
            .params
            .iter()
            .map(|p| format!("{}: {}", p.name, p.r#type))
            .collect();
        format!("{}({}) -> {}", m.name, params.join(", "), m.r#return)
    }

    /// Build a detail string for a free function signature.
    pub fn function_detail(f: &FreeFunction) -> String {
        let params: Vec<String> = f
            .params
            .iter()
            .map(|p| format!("{}: {}", p.name, p.r#type))
            .collect();
        let suffix = if f.variadic { ", ..." } else { "" };
        format!("{}({}{}) -> {}", f.name, params.join(", "), suffix, f.r#return)
    }
}
