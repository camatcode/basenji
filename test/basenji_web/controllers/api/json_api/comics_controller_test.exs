defmodule BasenjiWeb.JSONAPI.ComicsControllerTest do
  use BasenjiWeb.ConnCase

  alias Basenji.Comics
  alias BasenjiWeb.JSONAPI.ComicsController

  @moduletag :capture_log

  doctest ComicsController

  test "create comic", %{conn: conn} do
    %{resource_location: loc, format: format, page_count: page_count, released_year: r_year} = build(:comic)

    comic = %{
      title: Faker.Lorem.sentence(),
      description: Faker.Lorem.paragraph(2),
      author: Faker.Person.name(),
      format: format,
      page_count: page_count,
      released_year: r_year,
      resource_location: loc
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post(~p"/api/json/comics", %{"data" => %{"attributes" => comic, "type" => "comic"}})

    assert %{"data" => comic} = json_response(conn, 200)

    assert valid_comic?(comic)
  end

  test "get comic", %{conn: conn} do
    comic = insert(:comic)
    conn = get(conn, ~p"/api/json/comics/#{comic.id}", %{})

    assert %{"data" => comic} = json_response(conn, 200)
    assert valid_comic?(comic)
  end

  test "update comic", %{conn: conn} do
    %{resource_location: loc, format: format, page_count: page_count, released_year: r_year} =
      comic = insert(:comic) |> Map.from_struct()

    changes = %{
      title: Faker.Lorem.sentence(),
      description: Faker.Lorem.paragraph(2),
      author: Faker.Person.name(),
      format: format,
      page_count: page_count,
      released_year: r_year,
      resource_location: loc
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch(~p"/api/json/comics/#{comic.id}", %{"data" => %{"attributes" => changes, "type" => "comic"}})

    assert %{"data" => updated} = json_response(conn, 200)
    assert valid_comic?(updated)
    # changed
    assert updated["attributes"]["author"] == changes.author
    assert updated["attributes"]["description"] == changes.description
    assert updated["attributes"]["releasedYear"] == changes.released_year
    assert updated["attributes"]["title"] == changes.title

    # unchanged
    assert updated["attributes"]["format"] == "#{comic.format}"
    assert updated["id"] == comic.id
    assert updated["attributes"]["pageCount"] == comic.page_count
  end

  test "delete comic", %{conn: conn} do
    comic = insert(:comic)
    conn = delete(conn, ~p"/api/json/comics/#{comic.id}", %{})

    assert %{"data" => deleted} = json_response(conn, 200)
    assert deleted["id"] == comic.id

    {:error, :not_found} = Comics.get_comic(comic.id)
  end

  describe "list" do
    test "lists comics", %{conn: conn} do
      insert_list(100, :comic)
      conn = get(conn, ~p"/api/json/comics", %{})

      assert %{"data" => comics} = json_response(conn, 200)
      refute Enum.empty?(comics)

      comics
      |> Enum.each(fn comic ->
        assert valid_comic?(comic)
      end)
    end

    test "order", %{conn: conn} do
      insert_list(10, :comic)

      [:title, :author, :description, :resourceLocation, :releasedYear, :pageCount]
      |> Enum.each(fn order ->
        conn = get(conn, ~p"/api/json/comics", %{"sort" => "#{order}"})
        assert %{"data" => comics} = json_response(conn, 200)
        refute Enum.empty?(comics)

        ordered_fields =
          comics
          |> Enum.map(fn %{"attributes" => attributes} ->
            attributes["#{order}"]
          end)

        assert ordered_fields
      end)
    end

    test "search by", %{conn: conn} do
      comics = insert_list(10, :comic)

      Enum.each(comics, fn comic ->
        [:title, :author, :resource_location, :format, :released_year]
        |> Enum.each(fn search_term ->
          search_val = comic |> Map.from_struct() |> Map.get(search_term)
          conn = get(conn, ~p"/api/json/comics", %{"#{search_term}" => search_val})
          assert %{"data" => results} = json_response(conn, 200)
          refute Enum.empty?(results)
          [_result] = Enum.filter(results, fn c -> c["id"] == comic.id end)
        end)
      end)
    end

    test "search_by time", %{conn: conn} do
      insert_list(10, :comic)
      :timer.sleep(1000)
      dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      inserted = insert(:comic)
      # inserted_after
      conn = get(conn, ~p"/api/json/comics", %{"filter" => %{"inserted_after" => "#{dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [_result] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
      # inserted_before
      conn = get(conn, ~p"/api/json/comics", %{"filter" => %{"inserted_before" => "#{dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [] = Enum.filter(results, fn c -> c["id"] == inserted.id end)

      updated_dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      {:ok, _updated} = Comics.update_comic(inserted, %{title: Faker.Lorem.sentence()})
      conn = get(conn, ~p"/api/json/comics", %{"filter" => %{"updated_after" => "#{updated_dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [_result] = Enum.filter(results, fn c -> c["id"] == inserted.id end)

      conn = get(conn, ~p"/api/json/comics", %{"filter" => %{"updated_before" => "#{updated_dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
    end

    test "generic search", %{conn: conn} do
      a =
        insert(:comic,
          title: "Baz and Peace",
          author: "Arthur Smith",
          description: "A thrilling murder mystery"
        )

      b =
        insert(:comic,
          title: "Of foo and bar, or On The 25-fold Path",
          author: "Jane Smith",
          description: "Her best romance novel"
        )

      c =
        insert(:comic,
          title: "Potion-seller's guide to the galaxy",
          author: "Sam Major",
          description: "25 chapters of dense reading"
        )

      [{"and", [a.id, b.id]}, {"or", [b.id, c.id]}, {"it", [a.id, b.id]}, {"25", [b.id, c.id]}]
      |> Enum.each(fn {term, expected} ->
        conn = get(conn, ~p"/api/json/comics", %{"filter" => term, "sort" => "title"})
        assert %{"data" => results} = json_response(conn, 200)
        assert expected == results |> Enum.map(fn c -> c["id"] end)
      end)
    end
  end

  defp valid_comic?(%{"attributes" => attributes, "id" => id, "type" => "comic"}) do
    assert id
    assert attributes["author"]
    assert attributes["description"]
    assert attributes["format"]
    assert attributes["pageCount"]
    assert attributes["releasedYear"]
    assert attributes["resourceLocation"]
    assert attributes["title"]
    assert attributes["insertedAt"]
    assert attributes["updatedAt"]
    true
  end
end
