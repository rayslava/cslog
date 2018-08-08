#include <logging.hpp>
#include <gtest/gtest.h>
#include <gmock/gmock.h>

#ifndef TRAVIS_BUILD
constexpr std::chrono::milliseconds delay(1);
#else
constexpr std::chrono::milliseconds delay(10);
#endif

TEST(Logging, log)
{
  DEFAULT_LOGGING;
  testing::internal::CaptureStderr();
  auto sink = std::make_shared<logging::LogSinkPrinter>();
  logging::LoggerImpl::get().setOutput(std::static_pointer_cast<logging::LogSink>(sink));
  TRACE << "TRACE";
  std::this_thread::sleep_for(delay);
  DEBUG << "DEBUG";
  std::this_thread::sleep_for(delay);
  INFO << "INFO";
  std::this_thread::sleep_for(delay);
  WARNING << "WARNING";
  std::this_thread::sleep_for(delay);
  ERROR << "ERROR";
  std::this_thread::sleep_for(delay);
  FATAL << "FATAL";
  std::this_thread::sleep_for(delay);
  sink.reset();
  std::string output = testing::internal::GetCapturedStderr();
  ASSERT_THAT(output, testing::HasSubstr("TRACE"));
  ASSERT_THAT(output, testing::HasSubstr("DEBUG"));
  ASSERT_THAT(output, testing::HasSubstr("INFO"));
  ASSERT_THAT(output, testing::HasSubstr("WARNING"));
  ASSERT_THAT(output, testing::HasSubstr("ERROR"));
  ASSERT_THAT(output, testing::HasSubstr("FATAL"));
}
