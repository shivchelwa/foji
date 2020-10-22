// Code generated by foji {{ version }}, template: {{ templateFile }}; DO NOT EDIT.
{{- $pkgName := "pg" }}
{{- $table := .Table.Name}}
{{- $schema := .Table.Schema.Name}}
{{- $goName := case $table }}
{{- $hasSoftDeletes := .Table.Columns.Names.Contains "deleted_at"}}
{{- $mutableCols := (.Table.Columns.Filter .Table.PrimaryKeys.Paths).ByOrdinal.Names }}
{{- $mutableFields := (cases $mutableCols).Sprintf "row.%s"}}
{{- $scanFields := (cases .Table.Columns.ByOrdinal.Names).Sprintf "&row.%s"}}
{{- $selectFields := csv .Table.Columns.ByOrdinal.Names}}
{{- $PKs := cases .Table.PrimaryKeys.ByOrdinal.Names }}
{{- $PKFields := csv ($PKs.Sprintf "row.%s")}}
{{- $PKScanFields := csv ($PKs.Sprintf "&row.%s")}}

package {{ $pkgName }}

import (
	"context"

	"github.com/jackc/pgx/v4"
	"github.com/pkg/errors"

	"{{.Params.Package}}"
{{- range .Imports }}
	"{{ . }}"
{{- end }}
)

const querySelect{{$goName}} = `SELECT
	{{ $selectFields }}
FROM {{$schema}}.{{$table}} `

func scan{{$goName}}(rr pgx.Rows) ([]*{{$.PackageName}}.{{$goName}}, error) {
	var result []*{{$.PackageName}}.{{$goName}}
	for rr.Next() {
		row := {{$.PackageName}}.{{$goName}}{}
		err := rr.Scan({{ csv $scanFields }})
		if err != nil {
			return nil, errors.Wrap(err, "{{$goName}}.scan") // notest
		}
		result = append(result, &row)
	}
	return result, nil
}

func scanOne{{$goName}}(rr pgx.Row) (*{{$.PackageName}}.{{$goName}}, error) {
	row := {{$.PackageName}}.{{$goName}}{}
	err := rr.Scan({{ csv $scanFields }})
	if err != nil {
		return nil, errors.Wrap(err, "{{$goName}}.scanOne")
	}
	return &row, nil
}

// All retrieves all rows from '{{$table}}' as a slice of {{$goName}}.
func (r Repo) All{{$goName}}(ctx context.Context) ([]*{{$.PackageName}}.{{$goName}}, error) {
	query :=  querySelect{{$goName }}
{{- if $hasSoftDeletes -}}
	+ ` WHERE deleted_at is NULL `
{{- end}}
	q, err := r.db.Query(ctx,query)
	if err != nil {
		return nil, errors.Wrap(err, "{{$goName}}.All")
	}
	return scan{{$goName}}(q)
}

// Count gets size of '{{$table}}'.
func (r Repo) Count{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause) (int, error) {
	idx := 1
	query := `SELECT
		count(*) as count
		FROM {{$schema}}.{{$table}}
		WHERE ` + where.String(&idx)
		
	count := 0
	return count, r.db.QueryRow(ctx, query, where.Values()...).Scan(&count)
}

// Select retrieves rows from '{{$table}}' as a slice of {{$goName}}.
func (r Repo) Select{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause) ([]*{{$.PackageName}}.{{$goName}}, error) {
	idx := 1
	query := querySelect{{$goName}} + " WHERE " + where.String(&idx)
{{- if $hasSoftDeletes -}}
	+ ` AND deleted_at is NULL `
{{- end}}

	q, err := r.db.Query(ctx, query, where.Values()...)
	if err != nil {
		return nil, errors.Wrap(err, "{{$goName}}.Select")
	}
	return scan{{$goName}}(q)
}

// SelectOrder retrieves rows from '{{$table}}' as a slice of {{$goName}} in a particular order.
func (r Repo) SelectOrder{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause, orderBy {{$.PackageName}}.OrderByClause) ([]*{{$.PackageName}}.{{$goName}}, error) {
	idx := 1
	query := querySelect{{$goName}} + " WHERE " + where.String(&idx)
{{- if $hasSoftDeletes -}}
	+ ` AND deleted_at is NULL `
{{- end}} + " " + orderBy.String()

	q, err := r.db.Query(ctx, query, where.Values()...)
	if err != nil {
		return nil, errors.Wrap(err, "{{$goName}}.SelectOrder")
	}
	return scan{{$goName}}(q)
}

// First retrieve one row from '{{$table}}' when sorted by orderBy.
func (r Repo) First{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause, orderBy {{$.PackageName}}.OrderByClause) (*{{$.PackageName}}.{{$goName}}, error) {
	idx := 1
	query := querySelect{{$goName}} + " WHERE " + where.String(&idx)
{{- if $hasSoftDeletes -}}
	+ ` AND deleted_at is NULL `
{{- end}} + " " + orderBy.String() + " LIMIT 1"

	q := r.db.QueryRow(ctx, query, where.Values()...)
	return scanOne{{$goName}}(q)
}

{{- /* Takes the number of values to produce and produces a list of postgres
placeholders of the form $1, $2, etc */}}
{{- define "values" -}}
	{{$nums := numbers 1 . -}}
	{{$indices := $nums.Sprintf "$%s" -}}
	{{csv $indices -}}
{{end}}

// Insert inserts the row into the database.
func (r Repo) Insert{{$goName}}(ctx context.Context, row *{{$.PackageName}}.{{$goName}}) error {
const query = `INSERT INTO {{$schema}}.{{$table}}
{{- if gt (len $mutableCols) 0}}
	({{ csv $mutableCols }})
	VALUES
	({{template "values" (len $mutableCols) }})
{{- else}}
	DEFAULT VALUES
{{- end}}
	RETURNING
		{{csv .Table.PrimaryKeys.Names.Sort }}`
	q := r.db.QueryRow(ctx, query,{{- csv $mutableFields }})
	return q.Scan({{$PKScanFields}})
}
{{if gt (len $mutableCols) 0}}
// Update the Row in the database.
func (r Repo) Update{{$goName}}(ctx context.Context, row *{{$.PackageName}}.{{$goName}}) error {
	query := `UPDATE {{$schema}}.{{$table}}
	SET
		({{csv $mutableCols }}) =
		({{ template "values" (len $mutableCols) }})
	WHERE
	{{$last := sum (len .Table.PrimaryKeys) (len $mutableCols)}}
	{{- $first := inc (len $mutableCols)}}
	{{- range $x, $name := .Table.PrimaryKeys.Names.Sort -}}
		{{$name}} = ${{sum $first $x}}{{if lt (sum $x $first) $last}} AND {{end}}
	{{- end}}`

	_, err := r.db.Exec(ctx, query, {{csv $mutableFields }}, {{$PKFields}})
	return errors.Wrap(err, "{{$goName}}.update")
	}
{{end}}
// Set sets a single column on an existing row in the database.
func (r Repo) Set{{$goName}}(ctx context.Context, set {{$.PackageName}}.Where, where {{$.PackageName}}.WhereClause) (int64, error) {
	idx := 2
	query := `UPDATE {{$schema}}.{{$table}} SET ` +
		set.Field + " = $1 " +
		` WHERE ` +
		where.String(&idx)

	res, err := r.db.Exec(ctx, query, append([]interface{}{ set.Value }, where.Values()...)...)
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.set")
	}
	return res.RowsAffected(), nil
}
{{- if .Table.HasPrimaryKey }}
{{- if $hasSoftDeletes}}
// Delete{{$goName}} soft deletes the Row from the database. Returns the number of items soft deleted.
{{else}}
// Delete{{$goName}} deletes the Row from the database. Returns the number of items deleted.
{{end}}
func (r Repo) Delete{{$goName}}( ctx context.Context, {{ $.Parameterize .Table.PrimaryKeys "%s %s" $pkgName }}) (int64, error) {
	{{- if $hasSoftDeletes}}
	const query = `UPDATE {{$schema}}.{{$table}}
		SET deleted_at = now()
		WHERE
		{{ range $x, $name := .Table.PrimaryKeys.Names.Sort -}}
			{{$name}} = ${{inc $x}}{{if lt $x (sum (len $.Table.PrimaryKeys) -1)}} AND {{end}}
		{{- end}} AND deleted_at is NULL
		`
	{{- else }}
	const query = `DELETE FROM {{$schema}}.{{$table}} WHERE
		{{ range $x, $name := .Table.PrimaryKeys.Names.Sort -}}
			{{$name}} = ${{inc $x}}{{if lt $x (sum (len $.Table.PrimaryKeys) -1)}} AND {{end}}
		{{- end}}`{{- end}}
	res, err := r.db.Exec(ctx, query,
	{{- csv .Table.PrimaryKeys.Names.Sort.Camel  -}}
	)
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.Delete")
	}
	return res.RowsAffected(), nil
}
{{- if $hasSoftDeletes}}
// DeletePermanent{{$goName}} deletes the Row from the database. This bypasses the soft delete mechanism.
// Returns the number of items deleted.
func (r Repo) DeletePermanent{{$goName}}( ctx context.Context, {{ $.Parameterize .Table.PrimaryKeys "%s %s" $pkgName }}) (int64, error) {
	const query = `DELETE FROM {{$schema}}.{{$table}} WHERE
		{{ range $x, $name := .Table.PrimaryKeys.Names.Sort -}}
			{{$name}} = ${{inc $x}}{{if lt $x (sum (len $.Table.PrimaryKeys) -1)}} AND {{end}}
		{{- end}}`
	res, err := r.db.Exec(ctx, query,
	{{- csv .Table.PrimaryKeys.Names.Sort.Camel  -}}
	)
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.DeletePermanent")
	}
	return res.RowsAffected(), nil
}
{{end}}
{{end}}
// DeleteWhere{{$goName}} deletes Rows from the database and returns the number of rows deleted.
func (r Repo) DeleteWhere{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause) (int64, error) {
	idx := 1
{{ if $hasSoftDeletes}}
	query := `UPDATE {{$schema}}.{{$table}}
		SET deleted_at = now()
		WHERE ` + where.String(&idx) + ` AND deleted_at is NULL`
{{ else }}
	query := `DELETE FROM {{$schema}}.{{$table}}
		WHERE ` + where.String(&idx)
{{ end }}
	res, err := r.db.Exec(ctx, query, where.Values()...)
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.DeleteWhere")
	}
	return res.RowsAffected(), nil
}
{{ if $hasSoftDeletes}}
// UndeleteWhere{{$goName}} undeletes the Row from the database.
func (r Repo) Undelete{{$goName}}(ctx context.Context, {{ $.Parameterize .Table.PrimaryKeys "%s %s" $pkgName }}) (int64, error) {
	query := `UPDATE {{$schema}}.{{$table}}
	SET deleted_at = NULL
	WHERE
{{- range $x, $name := .Table.PrimaryKeys.Names.Sort }}
	{{$name}} = ${{inc $x}}{{if lt $x (sum (len $.Table.PrimaryKeys) -1)}} AND {{end}}
{{- end}} AND deleted_at is not NULL`

	res, err := r.db.Exec(ctx, query, {{ csv .Table.PrimaryKeys.Names.Sort.Camel  -}})
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.Undelete")
	}
	return res.RowsAffected(), nil
}

// DeleteWherePermanent{{$goName}} deletes the Row from the database. This bypasses the soft delete mechanism.
// Returns the number of items deleted.
func (r Repo) DeleteWherePermanent{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause) (int64, error) {
	idx := 1
	query := `DELETE FROM {{$schema}}.{{$table}}
		WHERE ` + where.String(&idx)

	res, err := r.db.Exec(ctx, query,  where.Values()...)
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.DeleteWherePermanent")
	}
	return res.RowsAffected(), nil
}

// UndeleteWhere{{$goName}} undeletes the Row from the database.
func (r Repo) UndeleteWhere{{$goName}}(ctx context.Context, where {{$.PackageName}}.WhereClause) (int64, error) {
	idx := 1
	query := `UPDATE {{$schema}}.{{$table}}
		SET deleted_at = null
		WHERE ` + where.String(&idx) + ` AND deleted_at is NOT NULL`

	res, err := r.db.Exec(ctx, query, where.Values()...)
	if err != nil {
		return 0, errors.Wrap(err, "{{$goName}}.UndeleteWhere")
	}
	return res.RowsAffected(), nil
}

{{ end -}}

{{ range .Table.Indexes -}}
	{{- $FuncName := print $goName "By" ((cases .Columns.Names).Join "") -}}
	{{- if $.Table.PrimaryKeys.Names.ContainsAll .Columns.Names -}}
		{{- $FuncName = print "Get" $goName -}}
	{{- end -}}
// {{$FuncName}} retrieves a row from '{{$.Table.Schema.Name}}.{{$.Table.Name}}'.
//
// Generated from index '{{.Name}}'.
func (r Repo) {{ $FuncName }}(ctx context.Context, {{ $.Parameterize .Columns "%s %s" $pkgName }}) ({{ if not .IsUnique }}[]{{ end }}*{{$$.PackageName}}.{{$goName}}, error) {
	query := querySelect{{$goName}} + ` WHERE {{csv .Columns.Names.Sort }} = {{template "values" (len .Columns)}}
{{- if $hasSoftDeletes }} AND deleted_at is NULL{{ end}}`

{{- if .IsUnique }}
	q := r.db.QueryRow(ctx, query, {{ csv (.Columns.Names.Sort.Camel) }})
{{- else }}
	q, err := r.db.Query(ctx, query, {{ csv (.Columns.Names.Sort.Camel) }})
	if err != nil {
		return nil, errors.Wrap(err, "{{$goName}}.{{ $FuncName }}")
	}
{{- end }}

{{- if .IsUnique }}
	return scanOne{{$goName}}(q)
{{- else }}
	return scan{{$goName}}(q)
{{- end }}
}

{{ end }}