#include "ruby.h"
#include "pg.h"

typedef struct {
  VALUE klass;
  long nfields;
  ID *ivars;
} row_materializer_t;

static VALUE cRowMaterializer;

static void rm_mark(void *ptr) {
  row_materializer_t *rm = (row_materializer_t *)ptr;
  if (rm) rb_gc_mark_movable(rm->klass);
}

static void rm_compact(void *ptr) {
  row_materializer_t *rm = (row_materializer_t *)ptr;
  if (rm) rm->klass = rb_gc_location(rm->klass);
}

static void rm_free(void *ptr) {
  row_materializer_t *rm = (row_materializer_t *)ptr;
  if (rm) {
    xfree(rm->ivars);
    xfree(rm);
  }
}

static size_t rm_memsize(const void *ptr) {
  const row_materializer_t *rm = (const row_materializer_t *)ptr;
  return rm ? sizeof(row_materializer_t) + (sizeof(ID) * rm->nfields) : 0;
}

static const rb_data_type_t rm_type = {
  "MiniSql::Postgres::Native::RowMaterializer",
  { rm_mark, rm_free, rm_memsize, rm_compact, },
  0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE rm_alloc(VALUE klass) {
  row_materializer_t *rm;
  VALUE obj = TypedData_Make_Struct(klass, row_materializer_t, &rm_type, rm);
  rm->klass = Qnil;
  rm->nfields = 0;
  rm->ivars = NULL;
  return obj;
}

static VALUE rm_initialize(VALUE self, VALUE row_class, VALUE fields) {
  row_materializer_t *rm;
  TypedData_Get_Struct(self, row_materializer_t, &rm_type, rm);

  Check_Type(fields, T_ARRAY);
  rm->klass = row_class;
  rm->nfields = RARRAY_LEN(fields);
  xfree(rm->ivars);
  rm->ivars = ALLOC_N(ID, rm->nfields);

  for (long i = 0; i < rm->nfields; i++) {
    VALUE field = rb_obj_as_string(rb_ary_entry(fields, i));
    VALUE ivar_name = rb_str_plus(rb_str_new_cstr("@"), field);
    rm->ivars[i] = rb_intern_str(ivar_name);
  }

  return self;
}

static void check_pgresult(t_pg_result *pgresult) {
  if (!pgresult->pgresult) {
    rb_raise(rb_eNoResultError, "PG::Result has been cleared");
  }
}

static VALUE rm_materialize(VALUE self, VALUE result, VALUE index) {
  row_materializer_t *rm;
  TypedData_Get_Struct(self, row_materializer_t, &rm_type, rm);

  int idx = NUM2INT(index);
  t_pg_result *pgresult = pgresult_get_this(result);
  check_pgresult(pgresult);

  int rows = PQntuples(pgresult->pgresult);
  if (idx < 0 || idx >= rows) {
    rb_raise(rb_eArgError, "invalid tuple number %d", idx);
  }

  VALUE row = rb_obj_alloc(rm->klass);
  long nfields = rm->nfields;
  ID *ivars = rm->ivars;
  t_typemap *typemap = pgresult->p_typemap;

  for (long col = 0; col < nfields; col++) {
    VALUE val = typemap->funcs.typecast_result_value(typemap, result, idx, col);
    rb_ivar_set(row, ivars[col], val);
  }

  return row;
}

static VALUE rm_materialize_all(VALUE self, VALUE result) {
  row_materializer_t *rm;
  TypedData_Get_Struct(self, row_materializer_t, &rm_type, rm);

  t_pg_result *pgresult = pgresult_get_this(result);
  check_pgresult(pgresult);

  int rows = PQntuples(pgresult->pgresult);
  long nfields = rm->nfields;
  ID *ivars = rm->ivars;
  t_typemap *typemap = pgresult->p_typemap;
  VALUE ary = rb_ary_new_capa(rows);

  for (int idx = 0; idx < rows; idx++) {
    VALUE row = rb_obj_alloc(rm->klass);
    for (long col = 0; col < nfields; col++) {
      VALUE val = typemap->funcs.typecast_result_value(typemap, result, idx, col);
      rb_ivar_set(row, ivars[col], val);
    }
    rb_ary_store(ary, idx, row);
  }

  return ary;
}

static VALUE rm_row_class(VALUE self) {
  row_materializer_t *rm;
  TypedData_Get_Struct(self, row_materializer_t, &rm_type, rm);
  return rm->klass;
}

void Init_pg_native(void) {
  VALUE mMiniSql = rb_define_module("MiniSql");
  VALUE mPostgres = rb_define_module_under(mMiniSql, "Postgres");
  VALUE mNative = rb_define_module_under(mPostgres, "Native");

  cRowMaterializer = rb_define_class_under(mNative, "RowMaterializer", rb_cObject);
  rb_define_alloc_func(cRowMaterializer, rm_alloc);
  rb_define_method(cRowMaterializer, "initialize", rm_initialize, 2);
  rb_define_method(cRowMaterializer, "materialize", rm_materialize, 2);
  rb_define_method(cRowMaterializer, "materialize_all", rm_materialize_all, 1);
  rb_define_method(cRowMaterializer, "row_class", rm_row_class, 0);
}
