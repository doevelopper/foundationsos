
#include <cppbdd101/features/step_definitions/DummyTestSteps.hpp>

using cucumber::ScenarioScope;
using namespace ::testing;

DummyCtx::DummyCtx()
{

}

DummyCtx::~DummyCtx()
{

}

void DummyCtx::loop(std::mutex & mutex, bool const & running)
{
    std::lock_guard<std::mutex> lock(mutex);
}

BEFORE_ALL()
{
    std::cout << "-------------------- (Before all scenarios)" << std::endl;
}

AFTER_ALL()
{
    std::cout << "-------------------- (After all scenarios)" << std::endl;
}

BEFORE()
{
    std::cout << "-------------------- (Before any scenario)" << std::endl;
}

BEFORE("@foo,@bar","@baz")
{
    std::cout << "Before scenario (\"@foo,@baz\",\"@bar\")" << std::endl;
}

AROUND_STEP("@baz")
{
    std::cout << "Around step (\"@baz\") ...before" << std::endl;
    // step->call();
    std::cout << "Around step (\"@baz\") ..after" << std::endl;
}

AFTER_STEP("@bar")
{
    std::cout << "After step (\"@bar\")" << std::endl;
}

AFTER("@foo")
{
    std::cout << "After scenario (\"@foo\")" << std::endl;
}

AFTER("@gherkin")
{
    std::cout << "After scenario (\"@gherkin\")" << std::endl;
}

GIVEN("^a step$")
{
    pending();
}


GIVEN("^execute dummy$")
{
 pending();
}

WHEN("^do nothing$")
{
 pending();
}

THEN("^should see$")
{
 pending();
}

THEN("^Success$")
{
 pending();
}

/*
GIVEN("^a dummy initialised with \"([^\"]*)\" and \"([^\"]*)\"$")
{
    REGEX_PARAM(std::string, hello_string);
    REGEX_PARAM(std::string, world_string);
    ScenarioScope<DummyCtx> context{};
    context->dummies.emplace_back(cpp101::Dummy{hello_string, world_string});
}

GIVEN("^the following dummies:$")
{
    TABLE_PARAM(dummy_params);
    ScenarioScope<DummyCtx> context{};
    const auto& dummies_table = dummy_params.hashes();

    for (const auto& table_row : dummies_table)
    {
       context->dummies.emplace_back(cpp101::Dummy{std::string{table_row.at("hello")},
       std::string{table_row.at("world")}});
    }
}

WHEN("^I command the dummy to say hello$")
{
    ScenarioScope<DummyCtx> context{};
    context->say_hello_result = context->dummies.front().speak();
}


WHEN("^I command the dummy (\\d+) to say hello$")
{
    REGEX_PARAM(size_t, dummy_index);
    ScenarioScope<DummyCtx> context{};
    context->say_hello_result = context->dummies.at(dummy_index).speak();
}


THEN("^the dummy should say \"([^\"]*)\"$")
{
    REGEX_PARAM(std::string, hello_world_string);
    ScenarioScope<DummyCtx> context{};
    ASSERT_STREQ(context->say_hello_result.c_str(), hello_world_string.c_str());
}
*/
